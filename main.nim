
import os, strutils, execute

when isMainModule:
  if paramCount() >= 2 and paramStr(1) == "-c":
    let codeSnippet = commandLineParams()[1..^1].join("\n")
    execute(codeSnippet, false) 
  elif paramCount() >= 1:
    let filename = paramStr(1)
    if fileExists(filename):
      let code = readFile(filename)
      execute(code, true)
    else:
      echo "Archivo no encontrado: ", filename
  else:
    echo "Uso: basic-a <archivo.ba> | -c \"codigo\""
