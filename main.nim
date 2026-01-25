import os, strutils, execute
when isMainModule:
  if commandLineParams().len == 0:
    quit("Uso: ./interpreter archivo.bas-a")
  let filename = commandLineParams()[0]
  if not fileExists(filename):
    quit("Archivo no existe: " & filename)
  let code = readFile(filename)
  execute(code)