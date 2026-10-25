#!/usr/bin/env python3
"""Inicializa app.db como el usuario 'app'. La flag vive solo aquí."""
import os
import sqlite3

DB = "/srv/app/app.db"
flag = os.environ["FLAG"]
admin_pw = os.environ["ADMIN_PW"]

con = sqlite3.connect(DB)
con.execute("CREATE TABLE users (username TEXT, password TEXT, role TEXT, flag TEXT)")
# admin primero: una inyección 'OR 1=1' devuelve esta fila.
con.execute("INSERT INTO users VALUES (?,?,?,?)", ("admin", admin_pw, "admin", flag))
con.execute("INSERT INTO users VALUES (?,?,?,?)", ("ana", "Primavera2024", "user", None))
con.execute("INSERT INTO users VALUES (?,?,?,?)", ("luis", "Verano.2024", "user", None))
con.commit()
con.close()
