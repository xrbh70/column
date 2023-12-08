#!/bin/bash
argu=0
encab=0
pie=0
trunc=0
val=0
s="  "
l=0
quitar=0
n=0
d=" "
del=0
#----------------------------Inicializacion de Variables
for arg in $(echo " $*") #Muy importante poner el espacio antes del $* es decir " $*" si no, no podra tomar parametros como -e y -n
do
  x=$arg
  case $x in
       "--comand"|"-c"    ) argu=1;;
       "--encab"|"-e"     ) encab=1;;
       "--pie"|"-p"       ) pie=1;;
       "--redond"|"-r"    ) redond=$(echo "$*" |awk '{for(a=1;a<=NF;a++) if($a=="--redond" || $a=="-r") if($(a+1) ~ /^[0-9]+$/) {print $(a+1);break}}')
                            case "$redond" in
                                 "2" )val=1;;
                                 ""  )redond=2;;
                                 *   )val=1;;
                            esac;;
       "--trunc"|"-t"     ) trunc=$(echo "$*" |awk '{for(a=1;a<=NF;a++)  if($a=="--trunc" || $a=="-t")  if($(a+1) ~ /^[0-9]+$/) {print $(a+1);break}}')
                            case "$trunc" in
                                 "80" )val=1;;
                                 ""   )trunc=80;;
                                 *    )val=1;;
                            esac;;
       "-s"               ) s=" |";;
       "-l"               ) s=" |"
                            l=1;;
       "--noespacio"|"-n" ) n=1;;
       "--delimit" |"-d"  ) d=$(echo "$*" |awk '{for(a=1;a<=NF;a++)  if($a=="--delimit" || $a=="-d")  if($(a+1) ~ /^[[:punct:]]$/) {print $(a+1);break}}')
                            case "$d" in
                                 ""   )d=" ";;
                                 *    )val=1;;
                            esac
                            del=1;;
       "--help"|"-h"      ) echo
                            echo "cols.awk [nombre del archivo] [--comand] [--encab] [--pie] [--redond [#]] [--trunc [#]] [-s] [-l] [--noespacio] [--delimit ["value"]] [--help]"
                            echo "                              [-c]       [-e]      [-p]    [-r       [#]] [-t      [#]]           [-n]          [-d        ["value"]] [-h]"
                            echo
                            echo "-c, --comand:    Escribe el comando awk que se ejecutara para realizar el formato del reporte al final"
                            echo "-e, --encab:     Omite el encabezado o linea numero 1 del reporte para su analisis"
                            echo "-p, --pie:       Omite el pie de pagina o la ultima linea del reporte para su analisis"
                            echo "-r, --redond:    Redondea las columnas flotantes a 2 cifras decimales por defecto o al numero indicado"
                            echo "-t, --trunc:     Trunca el reporte al numero de caracteres indicado, por default 80"
                            echo "-s:              Poner Pipe \"|\" como separador de columas"
                            echo "-l:              Dibujar tabla"
                            echo "-n, --noespacio: Quita el doble espacio usado para separar las columnas"
                            echo "-d, --delimit:   Indicarle al programa que el archivo a analizar esta separado por algun caracter de puntuacion"
                            echo "-h, --help:      Ayuda de este comando"
                            echo
                            echo "Ejemplo: cols.awk -encab -pie -redond"
                            echo "         ps -ef|cols.awk -e -t 100"
                            echo
                            exit 1;;
       *                  ) if [ $val -eq 1 ]
                            then
                                val=0
                            else
                                if [ -f $x ]
                                then
                                    param1=$x
                                else
                                    echo
                                    echo "Archivo no existe o parametros incorrectos \" $x \""
                                    echo "cols.awk $* " |grep --color -- " $x "
                                    echo
                                    echo "Favor de revisar la ayuda del comando: cols.awk -h"
                                    echo
                                    exit 1
                                fi
                            fi;;
  esac
done
#----------------------------Configuracion de opciones de ejecucion del programa
if tty >/dev/null
then
    cat -v $param1 >/tmp/$$column$$
else
    cat -v >/tmp/$$column$$
fi
#----------------------------Para saber si la informacion recibida viene por archivo (then) o por pipe (else)
if [ $trunc -ne 0 ]
then
    awk -v trunc=$trunc '{print substr($0,1,trunc)}' /tmp/$$column$$ >/tmp/$$column$$_1
    mv /tmp/$$column$$_1 /tmp/$$column$$
fi
#----------------------------Truncar la salida al numero de caracteres indicadoa
if [ $del -eq 1 ]
then
    sed -i 's/'"$d"'/ /g' /tmp/$$column$$
fi
#----------------------------Cambiar el delimitador por espacio para la ejecucion del programa
a=$(awk 'NR==1{a=NF}END{print NR, NF, a}' /tmp/$$column$$)
#----------------------------Determinar numero de lineas del reporte, numero de columnas de la ultima y primera linea del reporte
if [ $n -ne 0 ]
then
    if [ "$s" = "  " ]
    then
        s=" "
    else
        s="|"
    fi
fi
#---------------------------Saber si quieren el reporte con un espacio vacio o 2 espacios vacios
awk -v final="$a" \
    -v redond=$redond \
    -v encab=$encab \
    -v pie=$pie \
    -v s="$s" '
    function is_number(x) {return x+0 == x}
    function is_string(x) {return ! is_number(x)}
    function is_float(x)  {return x+0 == x && int(x) != x}
    #--------------------------------------------------------------------------------------------------------
    BEGIN                  {split(final, l, " ") #Pasar en modo array el numero de lineas del reporte, el numero de columnas de la ultima linea del reporte y el numero de columnas de la linea 1 del reporte
                            if   (encab==1)    records=1
                            else               records=0
                            if   (pie==1)      final=l[1]
                            else               final=l[1]+1}
    #--------------------------------------------------------------------------------------------------------
                           {for(a=1;a<=NF;a++) {if   (length($a)>b[a])      b[a]=length($a)}}      #b[a] Tamaño de la columna
                           #---------------------------------------------------------------------------------
    NR<final && NR>records {for(a=1;a<=NF;a++) {split($a, g, ".")
                                                if   (length(g[2])>h[a])    h[a]=length(g[2])      #h[a] Tamaño de la parte fraccionaria de la columna
                                                if   (length(g[1])>j[a])    j[a]=length(g[1])}}    #j[a] Tamaño de la parte entera de la columna
                           #---------------------------------------------------------------------------------
    NR<final && NR>records {for(a=1;a<=NF;a++) {if   (is_string($a)==1)     {c[a]="-"              #c[a] Alineacion izquierda/texto (-) derecha/numeros ("")
                                                                             e[a]="s"              #e[a] Si es texto (s) o flotante(f) o entero (d)
                                                                             d[a]=1}               #d[a] Inmutabilidad para columna texto
                                                                                                   #No es texto, evaluar si es flotante o entero
                                                if   (is_float($a)==1 )     {if(d[a]!=1) {c[a]=""  #c[a] Alineacion izquierda/texto (-) derecha/numeros ("")
                                                                                          e[a]="f" #e[a] Si es texto (s) o flotante(f) o entero (d)
                                                                                          f[a]=1}} #f[a] Inmutabilidad para columna flotante
                                                                                                   #No es texto, no es flotante, entonces es entero
                                                else if(d[a]!=1 && f[a]!=1) {c[a]=""               #c[a] Alineacion izquierda/texto (-) derecha/numeros ("")
                                                                             e[a]="d"}}}           #e[a] Si es texto (s) o flotante(f) o entero (d)
    #--------------------------------------------------------------------------------------------------------
    END {q="\047"                                                                             #comilla simple
         for(a in b) i[a]=b[a]                                                                #Pasar los valores del array b en i, para poder modificar los de i, ya que los de b se vuelven de lectura al llegar a END
         for(a in b) if(i[a]<h[a]+j[a]+1 && e[a]=="f") i[a]=h[a]+j[a]+1                       #Si la columna es flotante y es mas grande que la columna texto del analisis entonces tomar el nuevo valor de tamaño de columna
         for(a in b) if(redond!="" && e[a]=="f")       if(redond>=h[a]) i[a]=i[a]-h[a]+redond #Ajustar el tamaño de columna por el cambio de cifras decimales

         #Creacion del reporte en base al analisis del awk
         printf("awk    %sNR==%s       {printf(%s", q, 1, "\"")                                                                       #1
         if   (encab==1)             for(a=1;a<=l[3];a++) printf("%s%s%s%s%s", s, "%", "-", i[a], "s")                                #2
         else                        for(a=1;a<=l[3];a++) {if   (e[a]=="f") {if(redond!="") h[a]=redond                               #3
                                                                             printf("%s%s%s%d.%d%s", s, "%", c[a], i[a], h[a], e[a])} #4 Imprimir columnas flotantes y/o decimales
                                                           else             printf("%s%s%s%s%s", s, "%", c[a], i[a], e[a])}           #5 Imprimir puras columnas texto
         printf("%s\\n\", ", s)                                                                                                       #6
         for(a=1;a<=l[3]-1;a++)      printf("$%d, ", a)                                                                               #7
         print "$"a")}"                                                                                                               #8 Reporte de la primera linea
         #------------------------------------------------------------------------
         printf("        NR<%s && NR>1{printf(%s", l[1], "\"")                                                                        #1
         for(a in b)                 {if   (e[a]=="f")    {if(redond!="")   h[a]=redond                                               #3
                                                           printf("%s%s%s%d.%d%s", s, "%", c[a], i[a], h[a], e[a])}                   #4 Imprimir columnas flotantes y/o decimales
                                      else                printf("%s%s%s%s%s", s, "%", c[a], i[a], e[a])}                             #5 Imprimir puras columnas texto
         printf("%s\\n\", ", s)                                                                                                       #6
         for(a=1;a<=length(b)-1;a++) printf("$%d, ", a)                                                                               #7
         print "$"a")}"                                                                                                               #8 Reporte del contenido
         #------------------------------------------------------------------------
         printf("        NR==%s       {printf(%s", l[1], "\"")                                                                        #1
         if   (pie==1)               for(a=1;a<=l[2];a++) printf("%s%s%s%s%s", s, "%", "-", i[a], "s")                                #2
         else                        for(a=1;a<=l[2];a++) {if (e[a]=="f")   {if(redond!="") h[a]=redond                               #3
                                                                             printf("%s%s%s%d.%d%s", s, "%", c[a], i[a], h[a], e[a])} #4 Imprimir columnas flotantes y/o decimales
                                                           else             printf("%s%s%s%s%s", s, "%", c[a], i[a], e[a])}           #5 Imprimir puras columnas texto
         printf("%s\\n\", ", s)                                                                                                       #6
         for(a=1;a<=l[2]-1;a++)      printf("$%d, ", a)                                                                               #7
         print "$"a")}"q" $*"                                                                                                         #8 Reporte de la ultima linea
        }' /tmp/$$column$$ >/tmp/$$column$$.awk
#----------------------------Programa como tal
bash /tmp/$$column$$.awk /tmp/$$column$$ >/tmp/$$column$$_1
mv /tmp/$$column$$_1 /tmp/$$column$$
if [ $l -eq 1 ]
then
    echo -n -e "\e[4;49;39m"
fi
if [ "$redond" != "" ]
then
    cat /tmp/$$column$$ |
    sed -e 's/^  //' -e 's/^ //' -e 's/|/ /g' |
    cols.awk $(echo "$*" |awk '{for(a=1;a<=NF;a++)
                                   if($a=="--redond" || $a=="-r") if   ($(a+1) ~ /^[0-9]+$/) {$(a+1)=""        #Volver a ejecutar cols.awk con los mismos parametros enviados
                                                                                              continue}        #originalmente, pero sin la opcion de -redond, esto para ajustar
                                                                  else                       continue          #los espacios que quedan de mas por el cambio de tamaño de
                                   else                           if   ($a=="")              continue          #columna por las cifras decimales
                                                                  else                       printf("%s ", $a)
                                   print ""}')
    quitar=1                                                                                                   #Se activa esta bandera para que si esta presente la opcion -print
else                                                                                                           #solamente aparezca el -print de la segunda ejecucion del  comando cols.awk
    cat /tmp/$$column$$ |sed -e 's/^  //'  -e 's/^ //'
fi
if [ $l -eq 1 ]
then
    tput sgr0
fi
#----------------------------Ejecucion del programa
if [ "$argu" = "1" ]
then
    if [ $quitar -ne 1 ]
    then
        echo
        cat /tmp/$$column$$.awk |sed 's/$\*//'
        echo
    fi
fi
#----------------------------Ejecucion del parametro -print
rm -rf /tmp/$$column$$ /tmp/$$column$$.awk /tmp/$$pie$$ /tmp/$$encab$$
