#!/bin/bash
#==============================================================================
# cols - Formateador avanzado de columnas con análisis automático de tipos
# Versión: 2.1 - Compatible macOS/Linux
# Autor: Xavier
# Última modificación: 2026-01-13
# Dependencias: gawk (GNU awk), sed, bash 4.0+
#==============================================================================

set -euo pipefail

#==============================================================================
# SECCIÓN: Detección de awk apropiado
#==============================================================================
detect_awk() {
    if command -v gawk >/dev/null 2>&1; then
        echo "gawk"
    elif command -v awk >/dev/null 2>&1; then
        if awk --version 2>/dev/null | grep -qi "GNU Awk"; then
            echo "awk"
        else
            return 1
        fi
    else
        return 1
    fi
}

AWK_CMD=$(detect_awk) || {
    echo "Error: Se requiere GNU awk (gawk)" >&2
    echo >&2
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "En macOS instala con:" >&2
        echo "  brew install gawk" >&2
    else
        echo "En Linux instala con:" >&2
        echo "  sudo apt-get install gawk    # Debian/Ubuntu" >&2
        echo "  sudo yum install gawk        # RedHat/CentOS" >&2
    fi
    echo >&2
    exit 1
}

#==============================================================================
# SECCIÓN: Limpieza y trap
#==============================================================================
cleanup() {
    rm -rf /tmp/$$column$$ /tmp/$$column$$.awk /tmp/$$pie$$ /tmp/$$encab$$ 2>/dev/null
}
trap cleanup EXIT INT TERM HUP

#==============================================================================
# SECCIÓN: Variables y configuración
#==============================================================================
# Flags de opciones
declare -i argu=0 encab=0 pie=0 trunc=0 val=0 l=0 n=0 del=0 quitar=0

# Valores configurables
s="  "
d=" "
redond=""
param1=""

# Variables internas
readonly TMPFILE="/tmp/$$column$$"
readonly AWKFILE="/tmp/$$column$$.awk"

# Debug y recursión
DEBUG=${COLS_DEBUG:-0}
if [ -z "${COLS_AWK_LEVEL:-}" ]; then
    export COLS_AWK_LEVEL=1
else
    export COLS_AWK_LEVEL=$((COLS_AWK_LEVEL + 1))
    if [ "$COLS_AWK_LEVEL" -gt 3 ]; then
        echo "Error: Demasiados niveles de recursión" >&2
        exit 1
    fi
fi

debug_log() {
    if [ "$DEBUG" -eq 1 ]; then
        echo "[DEBUG] $*" >&2
    fi
}

debug_log "Sistema: $OSTYPE"
debug_log "Usando: $AWK_CMD"

#==============================================================================
# SECCIÓN: Análisis de parámetros
#==============================================================================
for arg in $(echo " $*") # Muy importante poner el espacio antes del $* es decir " $*" si no, no podrá tomar parámetros como -e y -n
do
  x=$arg
  case $x in
       "--comand"|"-c")
           argu=1
           debug_log "Opción: mostrar comando awk"
           ;;
       "--encab"|"-e")
           encab=1
           debug_log "Opción: omitir encabezado"
           ;;
       "--pie"|"-p")
           pie=1
           debug_log "Opción: omitir pie"
           ;;
       "--redond"|"-r")
           redond=$(echo "$*" | $AWK_CMD '{for(a=1;a<=NF;a++) if($a=="--redond" || $a=="-r") if($(a+1) ~ /^[0-9]+$/) {print $(a+1);break}}')
           case "$redond" in
                "2" ) val=1;;
                ""  ) redond=2
                      debug_log "Redondeo: default 2";;
                *   ) debug_log "Redondeo: $redond"
                      val=1;;
           esac
           ;;
       "--trunc"|"-t")
           trunc=$(echo "$*" | $AWK_CMD '{for(a=1;a<=NF;a++)  if($a=="--trunc" || $a=="-t")  if($(a+1) ~ /^[0-9]+$/) {print $(a+1);break}}')
           case "$trunc" in
                "80" ) val=1;;
                ""   ) trunc=80
                       debug_log "Truncado: default 80";;
                *    ) if [ "$trunc" -lt 10 ]; then
                           echo "Advertencia: trunc muy pequeño ($trunc), usando 20" >&2
                           trunc=20
                       fi
                       debug_log "Truncado: $trunc"
                       val=1;;
           esac
           ;;
       "-s")
           s=" |"
           debug_log "Opción: separador pipe"
           ;;
       "-l")
           s=" |"
           l=1
           debug_log "Opción: dibujar tabla"
           ;;
       "--noespacio"|"-n")
           n=1
           debug_log "Opción: sin espacios dobles"
           ;;
       "--delimit"|"-d")
           d=$(echo "$*" | $AWK_CMD '{for(a=1;a<=NF;a++)  if($a=="--delimit" || $a=="-d")  if($(a+1) ~ /^[[:punct:]]$/) {print $(a+1);break}}')
           case "$d" in
                ""   ) d=" ";;
                *    ) debug_log "Delimitador: '$d'"
                       val=1;;
           esac
           del=1
           ;;
       "--help"|"-h")
           cat << 'EOF'

NOMBRE
    cols - Formateador avanzado de columnas con análisis automático de tipos

SINOPSIS
    cols [ARCHIVO] [OPCIONES]
    comando | cols [OPCIONES]

DESCRIPCIÓN
    Analiza y formatea la salida en columnas con detección automática de:
    - Tipos de datos (texto, enteros, flotantes)
    - Alineación apropiada (izquierda para texto, derecha para números)
    - Ancho óptimo de columnas

    Sustituye al comando 'column' de Linux con funcionalidades avanzadas.
    Compatible con Linux y macOS (requiere GNU awk/gawk).

OPCIONES
    -c, --comand         Muestra el comando awk generado para el formato
    -e, --encab          Omite el encabezado (primera línea del análisis)
    -p, --pie            Omite el pie de página (última línea del análisis)
    -r, --redond [N]     Redondea flotantes a N decimales (default: 2)
    -t, --trunc [N]      Trunca la salida a N caracteres (default: 80)
    -s                   Usa '|' como separador de columnas
    -l                   Dibuja tabla con formato y líneas
    -n, --noespacio      Usa un espacio en lugar de dos entre columnas
    -d, --delimit [C]    Especifica delimitador de entrada (ej: ',', ';', '|')
    -h, --help           Muestra esta ayuda

EJEMPLOS
    # Formatear salida de ps sin encabezado, truncado a 120 caracteres
    ps -ef | cols -e -t 120

    # Archivo CSV con tabla dibujada y redondeo a 3 decimales
    cols datos.csv -d ',' -l -r 3

    # Reporte sin encabezado ni pie, con pipes como separadores
    cols reporte.txt -e -p -s

    # Ver el comando awk generado
    cols datos.txt -e -p -r 2 -c

INSTALACIÓN
    macOS:
        brew install gawk

    Linux (Debian/Ubuntu):
        sudo apt-get install gawk

    Linux (RedHat/CentOS):
        sudo yum install gawk

VARIABLES DE ENTORNO
    COLS_DEBUG=1         Activa mensajes de debug
    COLS_AWK_LEVEL       Control interno de recursión (no modificar)

NOTAS
    - El script detecta automáticamente si recibe datos por pipe o archivo
    - Las columnas de texto se alinean a la izquierda
    - Las columnas numéricas se alinean a la derecha
    - Los flotantes mantienen alineación decimal

AUTOR
    Xavier - 2026

EOF
           exit 0
           ;;
       *)
           if [ $val -eq 1 ]; then
               val=0
           else
               if [ -f "$x" ]; then
                   param1="$x"
                   debug_log "Archivo de entrada: $param1"
               else
                   echo >&2
                   echo "Archivo no existe o parámetros incorrectos: \"$x\"" >&2
                   echo "cols.awk $* " |grep --color -- " $x " >&2
                   echo >&2
                   echo "Favor de revisar la ayuda del comando: cols -h" >&2
                   echo >&2
                   exit 1
               fi
           fi
           ;;
  esac
done

#==============================================================================
# SECCIÓN: Procesamiento de entrada
#==============================================================================
debug_log "Procesando entrada..."

# Determinar fuente de datos y validar
if tty >/dev/null 2>&1; then
    # Entrada desde archivo
    if [ -z "$param1" ]; then
        echo "Error: Se requiere un archivo o entrada por pipe" >&2
        echo "Use: cols -h para ayuda" >&2
        exit 1
    fi
    cat -v "$param1" > "$TMPFILE"
else
    # Entrada desde pipe
    cat -v > "$TMPFILE"
fi

# Validar que hay datos
if [ ! -s "$TMPFILE" ]; then
    echo "Error: No hay datos para procesar" >&2
    exit 1
fi

debug_log "Datos recibidos: $(wc -l < "$TMPFILE") líneas"

#==============================================================================
# SECCIÓN: Truncar la salida al número de caracteres indicado
#==============================================================================
if [ $trunc -ne 0 ]; then
    $AWK_CMD -v trunc=$trunc '{print substr($0,1,trunc)}' "$TMPFILE" > "${TMPFILE}_1"
    mv "${TMPFILE}_1" "$TMPFILE"
    debug_log "Truncado aplicado a $trunc caracteres"
fi

#==============================================================================
# SECCIÓN: Cambiar el delimitador por espacio
#==============================================================================
if [ $del -eq 1 ]; then
    # Compatible con macOS y Linux
    if sed --version 2>/dev/null | grep -q GNU; then
        # GNU sed (Linux)
        sed -i 's/'"$d"'/ /g' "$TMPFILE"
    else
        # BSD sed (macOS)
        sed -i '' 's/'"$d"'/ /g' "$TMPFILE"
    fi
    debug_log "Delimitador '$d' reemplazado por espacio"
fi

#==============================================================================
# SECCIÓN: Determinar número de líneas y columnas del reporte
#==============================================================================
a=$($AWK_CMD 'NR==1{a=NF}END{print NR, NF, a}' "$TMPFILE")
debug_log "Análisis: $a (líneas columnas_última columnas_primera)"

#==============================================================================
# SECCIÓN: Configurar separador según opción -n
#==============================================================================
if [ $n -ne 0 ]; then
    if [ "$s" = "  " ]; then
        s=" "
    else
        s="|"
    fi
    debug_log "Separador ajustado por opción -n"
fi

#==============================================================================
# SECCIÓN: Generación del formateador AWK
#==============================================================================
debug_log "Generando comando awk formateador..."

$AWK_CMD -v final="$a" \
    -v redond=$redond \
    -v encab=$encab \
    -v pie=$pie \
    -v s="$s" \
    -v awkcmd="$AWK_CMD" '
    #==========================================================================
    # Funciones auxiliares para detección de tipos de datos
    #==========================================================================
    function is_number(x) {return x+0 == x}
    function is_string(x) {return ! is_number(x)}
    function is_float(x)  {return x+0 == x && int(x) != x}

    #==========================================================================
    BEGIN {
        # l[1] = número total de líneas del reporte
        # l[2] = número de columnas en la última línea del reporte
        # l[3] = número de columnas en la primera línea del reporte
        split(final, l, " ")

        # Determinar líneas a procesar según opciones
        if   (encab==1)    records=1
        else               records=0
        if   (pie==1)      final=l[1]
        else               final=l[1]+1
    }

    #==========================================================================
    # Primera pasada: determinar ancho máximo de cada columna
    #==========================================================================
    {
        for(a=1; a<=NF; a++) {
            if(length($a) > b[a]) b[a] = length($a)
        }
    }

    #==========================================================================
    # Segunda pasada: analizar tipos de datos y alineación
    # Solo procesa líneas entre el encabezado y el pie
    #==========================================================================
    NR<final && NR>records {
        for(a=1; a<=NF; a++) {
            # Separar parte entera y decimal
            split($a, g, ".")

            # h[a] = Tamaño máximo de la parte fraccionaria de la columna
            if(length(g[2]) > h[a]) h[a] = length(g[2])

            # j[a] = Tamaño máximo de la parte entera de la columna
            if(length(g[1]) > j[a]) j[a] = length(g[1])

            # Determinar tipo de dato y alineación
            if(is_string($a) == 1) {
                # Es texto
                c[a] = "-"    # c[a] = Alineación izquierda para texto
                e[a] = "s"    # e[a] = Tipo string
                d[a] = 1      # d[a] = Marcar como texto (inmutable)
            }
            else if(is_float($a) == 1) {
                # Es número flotante
                if(d[a] != 1) {
                    c[a] = ""     # c[a] = Alineación derecha para números
                    e[a] = "f"    # e[a] = Tipo flotante
                    f[a] = 1      # f[a] = Marcar como flotante (inmutable)
                }
            }
            else if(d[a] != 1 && f[a] != 1) {
                # Es número entero
                c[a] = ""     # c[a] = Alineación derecha para números
                e[a] = "d"    # e[a] = Tipo entero (digit)
            }
        }
    }

    #==========================================================================
    # END: Generar el comando awk que formateará la salida final
    #==========================================================================
    END {
        q = "\047"  # Comilla simple para el comando generado

        # Ajustar tamaños de columna según tipo y redondeo
        for(a in b) {
            i[a] = b[a]  # Copiar anchos a array modificable

            # Si es flotante y necesita más espacio por parte decimal
            if(i[a] < h[a] + j[a] + 1 && e[a] == "f") {
                i[a] = h[a] + j[a] + 1
            }

            # Ajustar por cambio en redondeo
            if(redond != "" && e[a] == "f") {
                if(redond >= h[a]) i[a] = i[a] - h[a] + redond
            }
        }

        #======================================================================
        # Generar formato para la PRIMERA LÍNEA (encabezado)
        #======================================================================
        printf("%s    %sNR==%s       {printf(%s", awkcmd, q, 1, "\"")

        if(encab == 1) {
            # Si se omite análisis del encabezado, formatear como texto
            for(a=1; a<=l[3]; a++) {
                printf("%s%s%s%s%s", s, "%", "-", i[a], "s")
            }
        }
        else {
            # Formatear según tipo detectado
            for(a=1; a<=l[3]; a++) {
                if(e[a] == "f") {
                    # Columna flotante
                    if(redond != "") h[a] = redond
                    printf("%s%s%s%d.%d%s", s, "%", c[a], i[a], h[a], e[a])
                }
                else {
                    # Columna texto o entera
                    printf("%s%s%s%s%s", s, "%", c[a], i[a], e[a])
                }
            }
        }

        printf("%s\\n\", ", s)
        for(a=1; a<=l[3]-1; a++) printf("$%d, ", a)
        print "$"a")}"

        #======================================================================
        # Generar formato para el CONTENIDO (líneas intermedias)
        #======================================================================
        printf("        NR<%s && NR>1{printf(%s", l[1], "\"")

        for(a in b) {
            if(e[a] == "f") {
                # Columna flotante
                if(redond != "") h[a] = redond
                printf("%s%s%s%d.%d%s", s, "%", c[a], i[a], h[a], e[a])
            }
            else {
                # Columna texto o entera
                printf("%s%s%s%s%s", s, "%", c[a], i[a], e[a])
            }
        }

        printf("%s\\n\", ", s)
        for(a=1; a<=length(b)-1; a++) printf("$%d, ", a)
        print "$"a")}"

        #======================================================================
        # Generar formato para la ÚLTIMA LÍNEA (pie)
        #======================================================================
        printf("        NR==%s       {printf(%s", l[1], "\"")

        if(pie == 1) {
            # Si se omite análisis del pie, formatear como texto
            for(a=1; a<=l[2]; a++) {
                printf("%s%s%s%s%s", s, "%", "-", i[a], "s")
            }
        }
        else {
            # Formatear según tipo detectado
            for(a=1; a<=l[2]; a++) {
                if(e[a] == "f") {
                    # Columna flotante
                    if(redond != "") h[a] = redond
                    printf("%s%s%s%d.%d%s", s, "%", c[a], i[a], h[a], e[a])
                }
                else {
                    # Columna texto o entera
                    printf("%s%s%s%s%s", s, "%", c[a], i[a], e[a])
                }
            }
        }

        printf("%s\\n\", ", s)
        for(a=1; a<=l[2]-1; a++) printf("$%d, ", a)
        print "$"a")}"q" $*"
    }
' "$TMPFILE" > "$AWKFILE"

debug_log "Comando awk generado exitosamente"

#==============================================================================
# SECCIÓN: Ejecución del formateador
#==============================================================================
debug_log "Ejecutando formateador..."

if ! bash "$AWKFILE" "$TMPFILE" > "${TMPFILE}_1"; then
    echo "Error al ejecutar el formateador" >&2
    exit 1
fi

mv "${TMPFILE}_1" "$TMPFILE"

#==============================================================================
# SECCIÓN: Aplicar formato de tabla si se solicita (-l)
#==============================================================================
if [ $l -eq 1 ]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS - usar printf
        printf "\033[4;49;39m"
    else
        # Linux - echo con -e funciona
        echo -n -e "\e[4;49;39m"
    fi
    debug_log "Aplicando formato de tabla"
fi

#==============================================================================
# SECCIÓN: Reajuste por cambio de redondeo (recursión)
#==============================================================================
if [ "$redond" != "" ]; then
    debug_log "Aplicando reajuste por redondeo..."

    cat "$TMPFILE" |
    sed -e 's/^  //' -e 's/^ //' -e 's/|/ /g' |
    cols.awk $(echo "$*" | $AWK_CMD '{for(a=1;a<=NF;a++)
                                   if($a=="--redond" || $a=="-r") if   ($(a+1) ~ /^[0-9]+$/) {$(a+1)=""
                                                                                              continue}
                                                                  else                       continue
                                   else                           if   ($a=="")              continue
                                                                  else                       printf("%s ", $a)
                                   print ""}')
    quitar=1
else
    cat "$TMPFILE" |sed -e 's/^  //'  -e 's/^ //'
fi

#==============================================================================
# SECCIÓN: Desactivar formato de tabla
#==============================================================================
if [ $l -eq 1 ]; then
    tput sgr0  # Reset de formato
fi

#==============================================================================
# SECCIÓN: Mostrar comando generado si se solicita (-c)
#==============================================================================
if [ "$argu" = "1" ]; then
    if [ $quitar -ne 1 ]; then
        echo
        cat "$AWKFILE" |sed 's/$\*//'
        echo
        debug_log "Comando awk mostrado"
    fi
fi

debug_log "Proceso completado exitosamente"

# Limpieza automática por trap
exit 0
