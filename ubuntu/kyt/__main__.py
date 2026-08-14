from kyt import *
from importlib import import_module
from kyt.modules import ALL_MODULES

for module_name in ALL_MODULES:
    import_module("kyt.modules." + module_name)

bot.run_until_disconnected()
