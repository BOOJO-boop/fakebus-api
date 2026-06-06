from flask import Flask, request, jsonify
from flask_cors import CORS
import mysql.connector
import os

app = Flask(__name__)
CORS(app)

def conectar():
    return mysql.connector.connect(
        host=os.environ.get('MYSQL_HOST', 'https://fakebus-api-production.up.railway.app'),
        user=os.environ.get('MYSQL_USER', 'root'),
        password=os.environ.get('MYSQL_PASSWORD', ''),
        database=os.environ.get('MYSQL_DATABASE', 'fakebus_db'),
        port=int(os.environ.get('MYSQL_PORT', 3306))
    )

# REGISTRO
@app.route('/registro', methods=['POST'])
def registro():
    data = request.json
    try:
        db = conectar()
        cursor = db.cursor()
        cursor.execute(
            "INSERT INTO usuarios (nombre, correo, contrasena, rol) VALUES (%s, %s, %s, %s)",
            (data['nombre'], data['correo'], data['contrasena'], 'pasajero')
        )
        db.commit()
        return jsonify({"mensaje": "Usuario registrado correctamente"}), 201
    except Exception as e:
        return jsonify({"error": str(e)}), 400
    finally:
        db.close()

# LOGIN
@app.route('/login', methods=['POST'])
def login():
    data = request.json
    try:
        db = conectar()
        cursor = db.cursor(dictionary=True)
        cursor.execute(
            "SELECT * FROM usuarios WHERE correo=%s AND contrasena=%s",
            (data['correo'], data['contrasena'])
        )
        usuario = cursor.fetchone()
        if usuario:
            return jsonify({"mensaje": "Login exitoso", "usuario": usuario}), 200
        else:
            return jsonify({"error": "Correo o contraseña incorrectos"}), 401
    except Exception as e:
        return jsonify({"error": str(e)}), 400
    finally:
        db.close()

# OBTENER CAMIONES CON OCUPACIÓN Y PUNTOS DE RUTA
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

# OBTENER PASAJEROS ACTUALES DE UN CAMIÓN
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

# ACTUALIZAR UBICACIÓN GPS DESDE LA APP DEL CHOFER
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

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(host='0.0.0.0', port=port)