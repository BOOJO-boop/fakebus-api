from flask import Flask, request, jsonify
from flask_cors import CORS
import mysql.connector
import os
import random
import secrets
import logging
import requests
from datetime import datetime, timedelta
from functools import wraps
import bcrypt

app = Flask(__name__)
CORS(app)

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("fakebus")

# ───────────────────── Configuración de correo (Brevo) ─────────────────────
BREVO_API_KEY = os.environ.get('BREVO_API_KEY', '')
EMAIL_REMITENTE = os.environ.get('EMAIL_REMITENTE', '')

# Duración de la sesión (token simple)
DURACION_TOKEN = timedelta(hours=12)

# ───────────────────── Variables de entorno requeridas ─────────────────────
_REQUIRED_ENV = ['MYSQL_HOST', 'MYSQL_USER', 'MYSQL_PASSWORD', 'MYSQL_DATABASE']
_faltantes = [v for v in _REQUIRED_ENV if not os.environ.get(v)]
if _faltantes:
    # No ponemos un default falso (como una URL) porque eso oculta el error
    # real y hace que la app intente conectar a un lugar sin sentido.
    logger.warning(
        "Faltan variables de entorno de MySQL: %s. "
        "La app usará valores de desarrollo local, pero en Railway esto debe "
        "estar configurado explícitamente.", _faltantes
    )


def conectar():
    return mysql.connector.connect(
        host=os.environ.get('MYSQL_HOST', 'localhost'),
        user=os.environ.get('MYSQL_USER', 'root'),
        password=os.environ.get('MYSQL_PASSWORD', ''),
        database=os.environ.get('MYSQL_DATABASE', 'fakebus_db'),
        port=int(os.environ.get('MYSQL_PORT', 3306))
    )


def error_generico(mensaje_log, status=400, mensaje_cliente="Ocurrió un error, intenta de nuevo"):
    """Loguea el detalle real en el servidor y regresa un mensaje genérico al cliente."""
    logger.error(mensaje_log)
    return jsonify({"error": mensaje_cliente}), status


def campos_requeridos(data, campos):
    """Regresa la lista de campos que faltan o vienen vacíos en el JSON recibido."""
    if data is None:
        return campos
    return [c for c in campos if not str(data.get(c, '')).strip()]


def requiere_token(f):
    """
    Decorador para proteger rutas sensibles (actualizar ubicación, cambiar estado de ruta).
    Espera un header: Authorization: Bearer <token>
    Valida que el token exista, no haya expirado, y que pertenezca al id_camion
    que la petición dice representar.
    """
    @wraps(f)
    def wrapper(*args, **kwargs):
        auth_header = request.headers.get('Authorization', '')
        if not auth_header.startswith('Bearer '):
            return jsonify({"error": "No autorizado"}), 401
        token = auth_header.replace('Bearer ', '').strip()

        data = request.json or {}
        id_camion = data.get('id_camion')
        if id_camion is None:
            return jsonify({"error": "Falta id_camion"}), 400

        db = conectar()
        try:
            cursor = db.cursor(dictionary=True)
            cursor.execute(
                "SELECT token_sesion, token_expira FROM usuarios "
                "WHERE id_autobus=%s AND rol='camionero'",
                (id_camion,)
            )
            usuario = cursor.fetchone()

            if (not usuario
                    or usuario['token_sesion'] != token
                    or usuario['token_expira'] is None
                    or datetime.now() > usuario['token_expira']):
                return jsonify({"error": "Token inválido o expirado"}), 401
        finally:
            db.close()

        return f(*args, **kwargs)
    return wrapper


def enviar_correo(destinatario, codigo):
    """Envía el código OTP por correo usando la API HTTPS de Brevo."""
    cuerpo_html = f"""
    <p>Hola,</p>
    <p>Recibimos una solicitud para recuperar tu contraseña en FakeBus.</p>
    <p><strong>Tu código de verificación es: {codigo}</strong></p>
    <p>Este código expira en 10 minutos. Si tú no solicitaste este cambio, ignora este correo.</p>
    <p>— Equipo FakeBus</p>
    """

    response = requests.post(
        'https://api.brevo.com/v3/smtp/email',
        headers={
            'accept': 'application/json',
            'api-key': BREVO_API_KEY,
            'content-type': 'application/json',
        },
        json={
            'sender': {'name': 'FakeBus', 'email': EMAIL_REMITENTE},
            'to': [{'email': destinatario}],
            'subject': 'Tu código de recuperación - FakeBus',
            'htmlContent': cuerpo_html,
        },
        timeout=15,
    )

    if response.status_code not in (200, 201):
        raise Exception(f"Brevo error: {response.status_code} - {response.text}")


# ───────────────────── REGISTRO ─────────────────────
@app.route('/registro', methods=['POST'])
def registro():
    data = request.json
    faltan = campos_requeridos(data, ['nombre', 'correo', 'contrasena'])
    if faltan:
        return jsonify({"error": f"Faltan campos: {', '.join(faltan)}"}), 400

    try:
        # Hashear la contraseña antes de guardarla
        hash_pass = bcrypt.hashpw(data['contrasena'].encode('utf-8'), bcrypt.gensalt())

        db = conectar()
        cursor = db.cursor()
        cursor.execute(
            "INSERT INTO usuarios (nombre, correo, contrasena, rol) VALUES (%s, %s, %s, %s)",
            (data['nombre'], data['correo'], hash_pass.decode('utf-8'), 'pasajero')
        )
        db.commit()
        return jsonify({"mensaje": "Usuario registrado correctamente"}), 201
    except mysql.connector.IntegrityError:
        return jsonify({"error": "Ese correo ya está registrado"}), 409
    except Exception as e:
        return error_generico(f"Error en /registro: {e}")
    finally:
        db.close()


# ───────────────────── LOGIN ─────────────────────
@app.route('/login', methods=['POST'])
def login():
    data = request.json
    faltan = campos_requeridos(data, ['correo', 'contrasena'])
    if faltan:
        return jsonify({"error": f"Faltan campos: {', '.join(faltan)}"}), 400

    try:
        db = conectar()
        cursor = db.cursor(dictionary=True)
        cursor.execute(
            "SELECT * FROM usuarios WHERE correo=%s",
            (data['correo'],)
        )
        usuario = cursor.fetchone()

        if usuario and bcrypt.checkpw(
            data['contrasena'].encode('utf-8'),
            usuario['contrasena'].encode('utf-8')
        ):
            # NOTA: id_autobus ya viene de la BD (columna real de la tabla
            # usuarios). Antes aquí se sobreescribía con un valor fijo (1)
            # para todos los camioneros, lo cual hacía que todos los
            # choferes reportaran el mismo camión. Se eliminó ese bug.

            token = None
            if usuario.get('rol') == 'camionero':
                token = secrets.token_hex(32)
                expira = datetime.now() + DURACION_TOKEN
                cursor_update = db.cursor()
                cursor_update.execute(
                    "UPDATE usuarios SET token_sesion=%s, token_expira=%s WHERE correo=%s",
                    (token, expira, usuario['correo'])
                )
                db.commit()

            # No regresamos el hash de la contraseña al frontend
            usuario.pop('contrasena', None)
            usuario.pop('token_sesion', None)
            usuario.pop('token_expira', None)

            respuesta = {"mensaje": "Login exitoso", "usuario": usuario}
            if token:
                respuesta["token"] = token
            return jsonify(respuesta), 200
        else:
            return jsonify({"error": "Correo o contraseña incorrectos"}), 401
    except Exception as e:
        return error_generico(f"Error en /login: {e}")
    finally:
        db.close()


# ───────────────────── SOLICITAR CÓDIGO DE RECUPERACIÓN ─────────────────────
@app.route('/solicitar_reset', methods=['POST'])
def solicitar_reset():
    data = request.json
    faltan = campos_requeridos(data, ['correo'])
    if faltan:
        return jsonify({"error": f"Faltan campos: {', '.join(faltan)}"}), 400
    correo = data.get('correo', '').strip()
    try:
        db = conectar()
        cursor = db.cursor(dictionary=True)
        cursor.execute("SELECT * FROM usuarios WHERE correo=%s", (correo,))
        usuario = cursor.fetchone()

        if not usuario:
            return jsonify({"error": "No existe una cuenta con ese correo"}), 404

        # Genera código de 6 dígitos
        codigo = str(random.randint(100000, 999999))
        expira = datetime.now() + timedelta(minutes=10)

        cursor.execute(
            "UPDATE usuarios SET codigo_reset=%s, codigo_reset_expira=%s WHERE correo=%s",
            (codigo, expira, correo)
        )
        db.commit()

        enviar_correo(correo, codigo)

        return jsonify({"mensaje": "Código enviado a tu correo"}), 200
    except Exception as e:
        return error_generico(f"Error en /solicitar_reset: {e}")
    finally:
        db.close()


# ───────────────────── VERIFICAR CÓDIGO ─────────────────────
@app.route('/verificar_codigo', methods=['POST'])
def verificar_codigo():
    data = request.json
    faltan = campos_requeridos(data, ['correo', 'codigo'])
    if faltan:
        return jsonify({"error": f"Faltan campos: {', '.join(faltan)}"}), 400
    correo = data.get('correo', '').strip()
    codigo = data.get('codigo', '').strip()
    try:
        db = conectar()
        cursor = db.cursor(dictionary=True)
        cursor.execute("SELECT * FROM usuarios WHERE correo=%s", (correo,))
        usuario = cursor.fetchone()

        if not usuario or usuario.get('codigo_reset') != codigo:
            return jsonify({"error": "Código incorrecto"}), 400

        if usuario.get('codigo_reset_expira') is None or datetime.now() > usuario['codigo_reset_expira']:
            return jsonify({"error": "El código expiró, solicita uno nuevo"}), 400

        return jsonify({"mensaje": "Código válido"}), 200
    except Exception as e:
        return error_generico(f"Error en /verificar_codigo: {e}")
    finally:
        db.close()


# ───────────────────── CAMBIAR CONTRASEÑA ─────────────────────
@app.route('/cambiar_password', methods=['POST'])
def cambiar_password():
    data = request.json
    faltan = campos_requeridos(data, ['correo', 'codigo', 'nueva_contrasena'])
    if faltan:
        return jsonify({"error": f"Faltan campos: {', '.join(faltan)}"}), 400
    correo = data.get('correo', '').strip()
    codigo = data.get('codigo', '').strip()
    nueva_contrasena = data.get('nueva_contrasena', '')

    try:
        db = conectar()
        cursor = db.cursor(dictionary=True)
        cursor.execute("SELECT * FROM usuarios WHERE correo=%s", (correo,))
        usuario = cursor.fetchone()

        if not usuario or usuario.get('codigo_reset') != codigo:
            return jsonify({"error": "Código incorrecto"}), 400

        if usuario.get('codigo_reset_expira') is None or datetime.now() > usuario['codigo_reset_expira']:
            return jsonify({"error": "El código expiró, solicita uno nuevo"}), 400

        hash_pass = bcrypt.hashpw(nueva_contrasena.encode('utf-8'), bcrypt.gensalt())

        cursor2 = db.cursor()
        cursor2.execute(
            "UPDATE usuarios SET contrasena=%s, codigo_reset=NULL, codigo_reset_expira=NULL WHERE correo=%s",
            (hash_pass.decode('utf-8'), correo)
        )
        db.commit()

        return jsonify({"mensaje": "Contraseña actualizada correctamente"}), 200
    except Exception as e:
        return error_generico(f"Error en /cambiar_password: {e}")
    finally:
        db.close()


# ───────────────────── CAMIONES ACTIVOS (Para la interfaz del pasajero) ─────────────────────
@app.route('/camiones', methods=['GET'])
def camiones():
    try:
        db = conectar()
        cursor = db.cursor(dictionary=True)
        cursor.execute("""
            SELECT c.id_camion, c.placa, c.modelo, c.capacidad_total,
                c.latitud, c.longitud, c.color_hex,
                IFNULL(r.pasajeros_actuales, 0) as pasajeros_actuales
            FROM camiones c
            LEFT JOIN (
                SELECT id_camion, pasajeros_actuales
                FROM registros_ocupacion
                WHERE id_registro = (
                    SELECT MAX(id_registro) FROM registros_ocupacion ro2
                    WHERE ro2.id_camion = registros_ocupacion.id_camion
                )
            ) r ON c.id_camion = r.id_camion
            WHERE c.activo = 1
        """)
        resultado = cursor.fetchall()

        if resultado:
            ids_camiones = [c['id_camion'] for c in resultado]
            formato = ','.join(['%s'] * len(ids_camiones))
            cursor.execute(f"""
                SELECT id_camion, latitud, longitud
                FROM puntos_ruta
                WHERE id_camion IN ({formato})
                ORDER BY id_camion, orden ASC
            """, tuple(ids_camiones))

            puntos_por_camion = {}
            for p in cursor.fetchall():
                puntos_por_camion.setdefault(p['id_camion'], []).append(
                    {'latitud': float(p['latitud']), 'longitud': float(p['longitud'])}
                )

            for c in resultado:
                c['puntos_ruta'] = puntos_por_camion.get(c['id_camion'], [])

        return jsonify(resultado), 200
    except Exception as e:
        return error_generico(f"Error en /camiones: {e}")
    finally:
        db.close()


# ───────────────────── PASAJEROS ACTUALES DE UN CAMIÓN ─────────────────────
@app.route('/pasajeros/<int:id_camion>', methods=['GET'])
def obtener_pasajeros(id_camion):
    try:
        db = conectar()
        cursor = db.cursor(dictionary=True)
        cursor.execute("""
            SELECT pasajeros_actuales 
            FROM registros_ocupacion 
            WHERE id_camion = %s 
            ORDER BY id_registro DESC 
            LIMIT 1
        """, (id_camion,))
        registro = cursor.fetchone()
        pasajeros = registro['pasajeros_actuales'] if registro else 0
        return jsonify({"pasajeros_actuales": pasajeros}), 200
    except Exception as e:
        return error_generico(f"Error en /pasajeros/{id_camion}: {e}")
    finally:
        db.close()


# ───────────────────── ACTUALIZAR UBICACIÓN GPS ─────────────────────
@app.route('/actualizar_ubicacion', methods=['POST'])
@requiere_token
def actualizar_ubicacion():
    data = request.json
    faltan = campos_requeridos(data, ['latitud', 'longitud', 'id_camion'])
    if faltan:
        return jsonify({"error": f"Faltan campos: {', '.join(faltan)}"}), 400
    try:
        db = conectar()
        cursor = db.cursor()
        cursor.execute("""
            UPDATE camiones 
            SET latitud = %s, longitud = %s 
            WHERE id_camion = %s
        """, (data['latitud'], data['longitud'], data['id_camion']))
        db.commit()
        return jsonify({"mensaje": "Ubicación actualizada correctamente"}), 200
    except Exception as e:
        return error_generico(f"Error en /actualizar_ubicacion: {e}")
    finally:
        db.close()


# ───────────────────── ENCENDER O APAGAR VISIBILIDAD DE LA RUTA ─────────────────────
@app.route('/cambiar_estado_ruta', methods=['POST'])
@requiere_token
def cambiar_estado_ruta():
    data = request.json
    faltan = campos_requeridos(data, ['activo', 'id_camion'])
    if faltan:
        return jsonify({"error": f"Faltan campos: {', '.join(faltan)}"}), 400
    try:
        db = conectar()
        cursor = db.cursor()
        cursor.execute("""
            UPDATE camiones 
            SET activo = %s 
            WHERE id_camion = %s
        """, (data['activo'], data['id_camion']))
        db.commit()
        return jsonify({"mensaje": "Estado de ruta actualizado"}), 200
    except Exception as e:
        return error_generico(f"Error en /cambiar_estado_ruta: {e}")
    finally:
        db.close()


if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port)