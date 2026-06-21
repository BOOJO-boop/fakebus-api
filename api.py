from flask import Flask, request, jsonify
from flask_cors import CORS
import mysql.connector
import os
import random
import smtplib
from email.mime.text import MIMEText
from datetime import datetime, timedelta
import bcrypt

app = Flask(__name__)
CORS(app)

# ───────────────────── Configuración de correo ─────────────────────
EMAIL_USER = os.environ.get('EMAIL_USER', '')
EMAIL_PASSWORD = os.environ.get('EMAIL_PASSWORD', '')


def conectar():
    return mysql.connector.connect(
        host=os.environ.get('MYSQL_HOST', 'https://fakebus-api-production.up.railway.app'),
        user=os.environ.get('MYSQL_USER', 'root'),
        password=os.environ.get('MYSQL_PASSWORD', ''),
        database=os.environ.get('MYSQL_DATABASE', 'fakebus_db'),
        port=int(os.environ.get('MYSQL_PORT', 3306))
    )


def enviar_correo(destinatario, codigo):
    """Envía el código OTP por correo usando Gmail SMTP."""
    asunto = "Tu código de recuperación - FakeBus"
    cuerpo = f"""Hola,

Recibimos una solicitud para recuperar tu contraseña en FakeBus.

Tu código de verificación es: {codigo}

Este código expira en 10 minutos. Si tú no solicitaste este cambio, ignora este correo.

— Equipo FakeBus
"""
    mensaje = MIMEText(cuerpo)
    mensaje['Subject'] = asunto
    mensaje['From'] = EMAIL_USER
    mensaje['To'] = destinatario

    with smtplib.SMTP('smtp.gmail.com', 587) as servidor:
        servidor.starttls()
        servidor.login(EMAIL_USER, EMAIL_PASSWORD)
        servidor.sendmail(EMAIL_USER, destinatario, mensaje.as_string())


# ───────────────────── REGISTRO ─────────────────────
@app.route('/registro', methods=['POST'])
def registro():
    data = request.json
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
    except Exception as e:
        return jsonify({"error": str(e)}), 400
    finally:
        db.close()


# ───────────────────── LOGIN ─────────────────────
@app.route('/login', methods=['POST'])
def login():
    data = request.json
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
            if usuario.get('rol') == 'camionero':
                usuario['id_autobus'] = 1
            # No regresamos el hash de la contraseña al frontend
            usuario.pop('contrasena', None)
            return jsonify({"mensaje": "Login exitoso", "usuario": usuario}), 200
        else:
            return jsonify({"error": "Correo o contraseña incorrectos"}), 401
    except Exception as e:
        return jsonify({"error": str(e)}), 400
    finally:
        db.close()


# ───────────────────── SOLICITAR CÓDIGO DE RECUPERACIÓN ─────────────────────
@app.route('/solicitar_reset', methods=['POST'])
def solicitar_reset():
    data = request.json
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
        return jsonify({"error": str(e)}), 400
    finally:
        db.close()


# ───────────────────── VERIFICAR CÓDIGO ─────────────────────
@app.route('/verificar_codigo', methods=['POST'])
def verificar_codigo():
    data = request.json
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
        return jsonify({"error": str(e)}), 400
    finally:
        db.close()


# ───────────────────── CAMBIAR CONTRASEÑA ─────────────────────
@app.route('/cambiar_password', methods=['POST'])
def cambiar_password():
    data = request.json
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
        return jsonify({"error": str(e)}), 400
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

        for c in resultado:
            cursor.execute("""
                SELECT latitud, longitud
                FROM puntos_ruta
                WHERE id_camion = %s
                ORDER BY orden ASC
            """, (c['id_camion'],))
            puntos = cursor.fetchall()
            c['puntos_ruta'] = [
                {'latitud': float(p['latitud']), 'longitud': float(p['longitud'])}
                for p in puntos
            ]

        return jsonify(resultado), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 400
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
        return jsonify({"error": str(e)}), 400
    finally:
        db.close()


# ───────────────────── ACTUALIZAR UBICACIÓN GPS ─────────────────────
@app.route('/actualizar_ubicacion', methods=['POST'])
def actualizar_ubicacion():
    data = request.json
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
        return jsonify({"error": str(e)}), 400
    finally:
        db.close()


# ───────────────────── ENCENDER O APAGAR VISIBILIDAD DE LA RUTA ─────────────────────
@app.route('/cambiar_estado_ruta', methods=['POST'])
def cambiar_estado_ruta():
    data = request.json
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
        return jsonify({"error": str(e)}), 400
    finally:
        db.close()


if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port)