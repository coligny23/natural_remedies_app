import sys
import argostranslate.package as P

available = P.get_available_packages()
pkg = next((p for p in available if p.from_code == "en" and p.to_code == "sw"), None)
if not pkg:
    sys.exit("ERROR: en->sw Argos package not found in index.")

P.install_from_path(pkg.download())
print("Installed:", pkg)
