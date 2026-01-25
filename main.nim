# main.nim
import os, strutils, execute

when isMainModule:
  if paramCount() >= 2 and paramStr(1) == "-c":
    # Tomamos el código pasado como argumento
    let codeSnippet = paramStr(2)
    execute(codeSnippet)  # Ejecuta el snippet directamente
  elif paramCount() >= 1:
    let filename = paramStr(1)
    if fileExists(filename):
      let code = readFile(filename)
      execute(code)
    else:
      echo "Archivo no encontrado: ", filename
  else:
    echo "Uso: basic-a <archivo.ba> | -c \"codigo\""
