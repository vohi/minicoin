@echo off
echo Hello runner!
echo Args received:
for %%i in (%*) DO ECHO '%%i'

>&2 echo "Testing stderr"
