from telethon import *
import datetime as DT
from telethon import *
import requests,time,os,subprocess,re,sqlite3,sys,random,base64,json,math
import logging

logging.basicConfig(level=logging.INFO)
uptime = DT.datetime.now()

VAR_PATH = os.environ.get("KYT_VAR_PATH", "/usr/bin/kyt/var.txt")
if not os.path.isfile(VAR_PATH):
    VAR_PATH = os.path.join(os.path.dirname(__file__), "var.txt")

exec(open(VAR_PATH, "r").read())

bot = TelegramClient("vpn_script_bot", "6", "eb06d4abfb49dc3eeb1aeb98ae0f581e").start(bot_token=BOT_TOKEN)

DB_PATH = os.path.join(os.path.dirname(VAR_PATH), "database.db")
try:
    open(DB_PATH)
except OSError:
    x = sqlite3.connect(DB_PATH)
    c = x.cursor()
    c.execute("CREATE TABLE admin (user_id)")
    c.execute("INSERT INTO admin (user_id) VALUES (?)", (ADMIN,))
    x.commit()

def get_db():
    x = sqlite3.connect(DB_PATH)
    x.row_factory = sqlite3.Row
    return x

def valid(id):
    db = get_db()
    x = db.execute("SELECT user_id FROM admin").fetchall()
    a = [v[0] for v in x]
    if id in a:
        return "true"
    else:
        return "false"

def convert_size(size_bytes):
   if size_bytes == 0:
       return "0B"
   size_name = ("B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB")
   i = int(math.floor(math.log(size_bytes, 1024)))
   p = math.pow(1024, i)
   s = round(size_bytes / p, 2)
   return "%s %s" % (s, size_name[i])
