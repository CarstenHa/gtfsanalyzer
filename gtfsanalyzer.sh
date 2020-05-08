#!/bin/bash

# This Script is under GNU Lesser General Public License v3.0
# See: http://www.gnu.org/licenses/lgpl-3.0.html
# Please feel free to contact me coding@langstreckentouren.de

# Überprüfung, ob Programm gpxinfo installiert ist.
# type -p: Leere Ausgabe bei fehlendem Paket.
if [ -z "$(type -p gpxinfo)" ]; then
 read -p "Das Programm gpxinfo ist nicht installiert. Um den vollen Funktionsumfang nutzen zu können, mussen sie das Programm aus dem Paket python3-gpxpy (sudo apt-get install python3-gpxpy) installieren. Weiter mit [ENTER]"
fi

if [ ! -d "results" ]; then
  mkdir ./results
fi
if [ ! -d "gpx" ]; then
 mkdir ./gpx
fi

# Hier Überprüfung, ob GTFS-Dateien vorhanden sind.

rm -f ./analysis.tmp
rm -f ./verzweigung.tmp
rm -f ./routesandtrips.tmp
rm -f ./tripidlist.tmp
rm -f ./stopidlist.tmp
rm -f ./allehaltestellen.tmp

# *** Funktionen ***
operatorabfrage() {
 agencylist="$(cut -d, -f1,2 ./agency.txt | sed 's/\"//g;1d')"
 anzagency="$(echo "$agencylist" | wc -l)"

 echo "" >./verzweigung.tmp
 echo "Agencys:"
 for ((d=1 ; d<=(("$anzagency")) ; d++)); do
  echo "$agencylist" | sed -n ''$d'p' | cut -d, -f2 | sed 's/\(.*\)/['${d}'] - \1/'
  echo "elif [ \"\$agencyanswer\" == "\"$d\"" ]; then" >>./verzweigung.tmp
  echo " agencyid=\"$(echo "$agencylist" | sed -n ''$d'p' | cut -d, -f1)\"" >>./verzweigung.tmp
  echo " agencyname=\"$(echo "$agencylist" | sed -n ''$d'p' | cut -d, -f2)\"" >>./verzweigung.tmp
 done
 echo "fi" >>./verzweigung.tmp
 sed -i '2s/elif/if/1' ./verzweigung.tmp
    
 read -p "Bitte Operator (agency) auswählen: " agencyanswer
 source ./verzweigung.tmp
}
usage()
{
cat <<EOU

Syntax:	$0 [options] [param]
	$0 [option] [param] [option] [param]

$0 analysiert GTFS-Daten (Sollfahrplandaten). Erstellte GPX-Dateien befinden sich im (neu erstellten) Unterordner ./gpx und die entsprechenden Analyseergebnisse im (neu erstellten) Unterordner ./results 

Für die Analyse stehen folgende Optionen zur Verfügung:
 
Options:

   -g [param]		(gpx routes) Generiert GPX-Dateien für jede Variante (shape) einer bestimmten Route.
			benötigt einen weiteren Parameter in Form einer Routennummer.
			Beispiel: $0 -g 1S
   -h			gibt diese Hilfe aus.
   -l [param]		(list) option with mandatory parameter.
			benötigt einen weiteren Parameter in Form einer Routennummer.
			Beispiel: $0 -l routes       listet alle Routennummern einer agency auf.
			Beispiel: $0 -l stops        listet alle Haltestellen einer agency auf.
			Beispiel: $0 -l allstops     listet alle Haltestellen der GTFS-Daten auf.
   -o [param]		(only stops) Analysiert Haltestellen nach entsprechenden Suchstring.
			Für jede Haltestelle wird eine GPX-Datei erstellt.
			benötigt einen weiteren Parameter in Form eines Haltestellennamens.
			Beispiel: $0 -o "Berlin HBF"
   -s [param]		(shapes) Analysiert die verschiedenen Fahrtvarianten einer Route.
			benötigt einen weiteren Parameter in Form einer Routennummer.
			Beispiel: $0 -s 1S
   -s shapesingle	Listet Informationen zu einer bestimmten Shape-ID auf.
   -t [param]		(trips) Analysiert alle Trips eines bestimmten Verkehrsunternehmens (agency)
			benötigt einen weiteren Parameter in Form einer Routennummer.
			Beispiel: $0 -t 1S

EOU
}

# Überprüfung, ob eine Option angegeben wurde.
if [ $# == "0" ]; then
 echo "Es wird mindestens eine Option benötigt!"
 usage
 exit 2
fi

while getopts ho:t:s:g:l: opt

do 
 case $opt in

  h) usage
     exit 0
  ;;


  o) # *** Haltestellenauswertung ***
     stopauswahl="$(grep -i "$OPTARG" ./stops.txt)"
     anzhaltestellen="$(grep -icb "$OPTARG" ./stops.txt)"

     while true; do
      echo ""
      echo "$stopauswahl" | sed 's/^[^,]*,\"\([^\"]*\)\"\([^,]*\),\"\([^\"]*\)\"[^,]*,[^,]*,\"\([^\"]*\)\"[^,]*,\"\([^\"]*\)\"[^,]*,.*$/\3/'
      echo ""

      if [ "$anzhaltestellen" -gt "0" ]; then
       read -p "Auswahl [k]orrekt? Oder soll [n]eue Abfrage erfolgen? " stopantwort
      fi

      case "$stopantwort" in
        K|k|"") if [ "$anzhaltestellen" -gt "0" ]; then
                 echo "Haltestellenanalyse wird fortgesetzt ..."
                 break
                else 
                 echo "Es wurde keine Haltestelle ausgewählt."
                 read -p "Bitte neuen Haltestellennamen eingeben: " OPTARG
                 stopauswahl="$(grep -i "$OPTARG" ./stops.txt)"
                 anzhaltestellen="$(grep -icb "$OPTARG" ./stops.txt)"
                fi
         ;;
        N|n) read -p "Bitte neuen Haltestellennamen eingeben: " OPTARG
             stopauswahl="$(grep -i "$OPTARG" ./stops.txt)"
             anzhaltestellen="$(grep -icb "$OPTARG" ./stops.txt)"
         ;;
        *) echo "Fehlerhafte Eingabe!"
         ;;
      esac
     done

     echo ""
     echo "********* Haltestellen-Analyse **********" | tee ./analysis.tmp
     echo "Suchstring: $OPTARG" | tee -a ./analysis.tmp
     echo "Anzahl der analysierten Haltestellen: $anzhaltestellen" | tee -a ./analysis.tmp
     echo "*****************************************" | tee -a ./analysis.tmp

     for ((n=1 ; n<=(("$anzhaltestellen")) ; n++)); do

      echo "Haltestelle: ${n}:" | tee -a ./analysis.tmp

      # Wichtig! Die alte Datei muss hier gelöscht werden, weil sonst auch noch anderer Inhalt verarbeitet wird, der in die folgende Verarbeitung nicht rein gehört.
      rm -f ./routesandtrips.tmp

      stopline="$(echo "$stopauswahl" | sed -n ''$n'p')"
      stopid="$(echo "$stopline" | cut -d, -f1)"
      stopname="$(echo "$stopline" | sed 's/^[^,]*,\"\([^\"]*\)\"\([^,]*\),\"\([^\"]*\)\"[^,]*,[^,]*,\"\([^\"]*\)\"[^,]*,\"\([^\"]*\)\"[^,]*,.*$/\3/')"
      stoplat="$(echo "$stopline" | sed 's/^[^,]*,\"\([^\"]*\)\"\([^,]*\),\"\([^\"]*\)\"[^,]*,[^,]*,\"\([^\"]*\)\"[^,]*,\"\([^\"]*\)\"[^,]*,.*$/\4/')"
      stoplon="$(echo "$stopline" | sed 's/^[^,]*,\"\([^\"]*\)\"\([^,]*\),\"\([^\"]*\)\"[^,]*,[^,]*,\"\([^\"]*\)\"[^,]*,\"\([^\"]*\)\"[^,]*,.*$/\5/')"
      tripidlist="$(grep "$stopid" ./stop_times.txt | sort | cut -d, -f1)"
      # Zwei Kommas in der abgegrenzten Variablen wandeln alle Großbuschstaben in kleine um.
      dateiname="$(echo ${stopname,,} | sed 's/ /_/g')"

      echo "Name der Haltestelle: ${stopname}" | tee -a ./analysis.tmp
      echo "Stop-ID: ${stopid}" | tee -a ./analysis.tmp
      echo "Koordinaten (lat/lon): ${stoplat} ${stoplon}" | tee -a ./analysis.tmp

      anztrips="$(echo "$tripidlist" | wc -l)"
      echo "GPX wird generiert (${anztrips} Trips werden ausgewertet) ..."
      for ((o=1 ; o<=(("$anztrips")) ; o++)); do
        grep "$(echo "$tripidlist" | sed -n ''$o'p')" ./trips.txt | sed 's/\(^[^,]*\),\([^,]*\),[^,]*,\"\([^\"]*\)\"[^,]*,\"\([^\"]*\)\"\([^,]*\),[^,]*,[^,]*,\([^,]*\),.*$/\1,\3/' >>./routesandtrips.tmp
      done

      routelist="$(cat ./routesandtrips.tmp | sort | uniq)"
      anzroutes="$(echo "$routelist" | wc -l)"

      echo "Generiere GPX ..."
      echo "Name der GPX-Datei: "$dateiname"_"$stopid".gpx"
      echo "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\" ?>" >./"$dateiname"_"$stopid".gpx
      echo "<gpx version=\"1.1\" creator=\"${0}\">" >>./"$dateiname"_"$stopid".gpx
      echo "<wpt lat=\"$stoplat\" lon=\"$stoplon\">" >>./"$dateiname"_"$stopid".gpx
      echo "<name>${stopname}</name>" >>./"$dateiname"_"$stopid".gpx
      echo "<desc>Stop_id: ${stopid}</desc>" >>./"$dateiname"_"$stopid".gpx
      echo "<cmt>" >>./"$dateiname"_"$stopid".gpx
      echo "Folgende Linien halten an diesem Stop:" | tee -a ./analysis.tmp

      for ((p=1 ; p<=(("$anzroutes")) ; p++)); do
       routeid="$(echo "$routelist" | sed -n ''$p'p' | cut -d, -f1)"
       routename="$(grep '^'"${routeid}"',' ./routes.txt | sed 's/^[^,]*,[^,]*,\"\([^\"]*\)\"[^,]*,.*$/\1/')"
       endhaltestelle="$(echo "$routelist" | sed -n ''$p'p' | sed 's/^[^,]*,\(.*\)$/\1/')"
       echo "[ *** Route ${p} *** $routename (route_id: ${routeid}) nach ${endhaltestelle} ]" >>./"$dateiname"_"$stopid".gpx
       echo "Linie $routename (Route-ID: ${routeid}) nach ${endhaltestelle}" | tee -a ./analysis.tmp
      done

      echo "</cmt>" >>./"$dateiname"_"$stopid".gpx
      echo "</wpt>" >>./"$dateiname"_"$stopid".gpx
      echo "</gpx>" >>./"$dateiname"_"$stopid".gpx

      # Achtung! Existierende Dateien im Ordner werden überschrieben!
      mv -f ./"$dateiname"_"$stopid".gpx ./gpx/
      echo "*****************************************" | tee -a ./analysis.tmp

     done
     mv ./analysis.tmp ./results/`date +%Y%m%d_%H%M%S`_haltestellenanalyse_"$OPTARG".txt

  ;;

  # *** Ermittlung aller Trips einer bestimmten Route ***

  t) operatorabfrage
     # route_id ermitteln
     routeid="$(cut -d, -f1,2,3 ./routes.txt | grep '^.*,'$agencyid',\"'$OPTARG'\"' | cut -d, -f1)"

    if [ -n "$routeid" ]; then

     tripidlist="$(grep "$routeid" ./trips.txt | cut -d, -f3)"
     # Auf cut wird verzichtet, weil in den Haltestellennamen oft ein Komma vorkommt und dann das Ergebnis verfälscht wird.
     shapeidlist="$(grep "$routeid" ./trips.txt | sed 's/^[^,]*,[^,]*,[^,]*,\"[^\"]*\"[^,]*,\"[^\"]*\"[^,]*,[^,]*,[^,]*,\([^,]*\),[^,]*,.*$/\1/' | sort | uniq)"

     echo ""
     echo "** Ermittlung aller Trips einer Route *" | tee ./analysis.tmp
     anztripid="$(echo "$tripidlist" | wc -l)"
     anzshapeid="$(echo "$shapeidlist" | wc -l)"
     echo "Ausgewertete Route: $OPTARG" | tee -a ./analysis.tmp
     echo "Operator (agency): $agencyname" | tee -a ./analysis.tmp
     echo "$anztripid Trips gefunden (trip_id)." | tee -a ./analysis.tmp
     echo "$anzshapeid Fahrtvarianten gefunden (shape_id):" | tee -a ./analysis.tmp
     echo $shapeidlist | tee -a ./analysis.tmp
     echo "***************************************" | tee -a ./analysis.tmp
     echo ""
     echo "Die folgende Auswertung kann unter Umständen mehrere Minuten dauern."
     read -p "Sollen wirklich alle Routen jetzt ausgewertet werden (j/n)? " tripantwort
     case "$tripantwort" in
       Ja|ja|J|j|"") echo "Bearbeitung der Tripauswertung wird fortgesetzt ..."
        ;;
       Nein|nein|N|n) mv ./analysis.tmp ./results/`date +%Y%m%d_%H%M%S`_triplist_"$agencyname".txt
                      break
        ;;
       *) echo "Fehlerhafte Eingabe!" && break
        ;;
     esac
     echo ""

     for ((a=1 ; a<=(("$anztripid")) ; a++)); do

      unset abfahrtstart

      echo "Trip ${a}:" | tee -a ./analysis.tmp
      tripid="$(echo "$tripidlist" | sed -n ''$a'p')"
      trip="$(grep "$tripid" ./stop_times.txt)"
      shapeid="$(grep "$tripid" ./trips.txt | cut -d, -f8)"
      serviceid="$(grep "$tripid" ./trips.txt | cut -d, -f2)"

      anzstopsinroute="$(echo "$trip" | wc -l)"
      for ((b=1 ; b<=(("$anzstopsinroute")) ; b++)); do
       stopline="$(echo "$trip" | sed -n ''$b'p')"
       # Es wird nur die Zeit der ersten Haltestelle benötigt. Da Variable zu Beginn leer (unset;siehe oben), wird sie beim ersten Fund neu belegt und bleibt bestehen bis zum Ende der for-Schleife.
       if [ -z "$abfahrtstart" ]; then
        abfahrtstart="$(echo "$stopline" | cut -d, -f3 | sed 's/24\(:..:..\)/00\1/')"
       fi
       haltestellenid="$(echo "$stopline" | cut -d, -f4)"
       haltestelle="$(grep "$haltestellenid" ./stops.txt | sed 's/^[^,]*,[^,]*,\"\([^\"]*\)\".*$/\1/')"

       # Hier werden die erste und letzte Zeile angezeigt und in .tmp-Datei geschrieben.
       # Zwischenhalte werden nur in Datei geschrieben
       if [ "$b" == "1" ]; then
        echo "$stopline" | sed 's/\(^.*\),\(.*\),\(.*\),\(.*\),\(.*\),\(.*\),\(.*\),\(.*$\)/\3 '"$haltestelle"'/'
        echo "$stopline" | sed 's/\(^.*\),\(.*\),\(.*\),\(.*\),\(.*\),\(.*\),\(.*\),\(.*$\)/        \3 '"$haltestelle"'/' >>./analysis.tmp
       elif [ "$b" == "$anzstopsinroute" ]; then
        echo "$stopline" | sed 's/\(^.*\),\(.*\),\(.*\),\(.*\),\(.*\),\(.*\),\(.*\),\(.*$\)/\2 '"$haltestelle"'/'
        echo "$stopline" | sed 's/\(^.*\),\(.*\),\(.*\),\(.*\),\(.*\),\(.*\),\(.*\),\(.*$\)/\2         '"$haltestelle"'/' >>./analysis.tmp
        # Wird nur zur Auswertung bei der letzten Haltestelle benötigt.
        # für die Ausgaben: "Dauer der Fahrt" und "Ausgewertete Trip-ID".
        # Mit sed wird Datumsformat der Stunden von 24 Uhr auf 00 Uhr geändert, sonst passt Ergebnis nicht.
        ankunftundende="$(echo "$stopline" | cut -d, -f2 | sed 's/24\(:..:..\)/00\1/')"
       else
        echo "$stopline" | sed 's/\(^.*\),\(.*\),\(.*\),\(.*\),\(.*\),\(.*\),\(.*\),\(.*$\)/\2 \3 '"$haltestelle"'/' >>./analysis.tmp
       fi
      done

      verkehrstage="$(grep '^'"$serviceid"',' ./calendar.txt | cut -d, -f2-8 | sed 's/,/ /g;s/1/x/g;s/0/-/g')"
      verkehrst_plus="$(grep '^'"$serviceid"',' ./calendar_dates.txt | grep '^.*,.*,1' | sed 's/^[^,]*,\([^,]*\),1/\1/;s/\(....\)\(..\)\(..\)/\1-\2-\3/')"
      verkehrst_minus="$(grep '^'"$serviceid"',' ./calendar_dates.txt | grep '^.*,.*,2' | sed 's/^[^,]*,\([^,]*\),2/\1/;s/\(....\)\(..\)\(..\)/\1-\2-\3/')"


      echo "Verkehrstage (Mo-So): $verkehrstage" | tee -a ./analysis.tmp
      if [ -n "$verkehrst_plus" ]; then
       echo "Zusätzliche Verkehrstage:" | tee -a ./analysis.tmp
       echo "$verkehrst_plus" | sort | tee -a ./analysis.tmp
      fi
      if [ -n "$verkehrst_minus" ]; then
       echo "Fährt nicht an diesen Tagen:" | tee -a ./analysis.tmp
       echo "$verkehrst_minus" | sort | tee -a ./analysis.tmp
      fi

      # Auswertungen für Ausgabe "Dauer der Fahrt".
      Startdate=$(date -u -d "$abfahrtstart" +"%s")
      Finaldate=$(date -u -d "$ankunftundende" +"%s")

      echo "Dauer der Fahrt: $(date -u -d "0 $Finaldate sec - $Startdate sec" +%H:%M)"  | tee -a ./analysis.tmp

      echo "Trip-ID: $tripid" | tee -a ./analysis.tmp
      echo "Shape-ID: $shapeid" | tee -a ./analysis.tmp
      echo "Service-ID: $serviceid" | tee -a ./analysis.tmp
      echo "Haltestellen in Route: $anzstopsinroute" | tee -a ./analysis.tmp
      echo "***************************************" | tee -a ./analysis.tmp

      # Nur zum debugging verwenden:
      #read -p "Weiter"

     # Ende der a-Schleife
     done

     mv ./analysis.tmp ./results/`date +%Y%m%d_%H%M%S`_triplist_"$agencyname".txt

    else echo "Es wurde keine Route ${OPTARG} des Verkehrsunternehmens (agency) ${agencyname} gefunden. Um eine Liste aller Routen eines Verkehrsunternehmens zu erhalten, kann dieses Skript mit der Option -r aufgerufen werden."
    fi

  ;;

  # *** Ermittlung der Routenvariante(n) einer bestimmten Route ***

  s) operatorabfrage

     # ** shapesingle **

     if [ "$OPTARG" == "shapesingle" ]; then

      read -p "Bitte Shape-ID eingeben: " shapeid
      read -p "Bitte Routennummer eingeben: " OPTARG

      # route_id ermitteln
      routeid="$(cut -d, -f1,2,3 ./routes.txt | grep '^.*,'$agencyid',\"'$OPTARG'\"' | cut -d, -f1)"

      if [ -n "$routeid" ]; then

       tripidlist="$(grep "$routeid" ./trips.txt | cut -d, -f3)"
       # Auf cut wird verzichtet, weil in den Haltestellennamen oft ein Komma vorkommt und dann das Ergebnis verfälscht wird.
 
       echo ""
       echo "*** Ermittlung EINER Routenvariante ***" | tee ./analysis.tmp
       echo "Ausgewertete Route: $OPTARG" | tee -a ./analysis.tmp
       echo "Operator (agency): $agencyname" | tee -a ./analysis.tmp
       echo "Shape-ID: $shapeid" | tee -a ./analysis.tmp
       echo "***************************************" | tee -a ./analysis.tmp

       # ** Überprüfungen, ob diverse Angaben zur shape-id passen. **
       recheck="$(sed -n '/^[^,]*,[^,]*,[^,]*,\"[^\"]*\"[^,]*,\"[^\"]*\"[^,]*,[^,]*,[^,]*,'"$shapeid"',[^,]*,.*$/p' ./trips.txt | cut -d, -f1 | uniq)"
       # Überprüfung, ob shape-ID in shapes.txt vorhanden ist (anhand leerer Variable).
       if [ -z "$(cut -d, -f1 ./shapes.txt | grep $shapeid)" ]; then

        echo "Keine passende Shape-ID gefunden." | tee -a ./analysis.tmp

       # Überprüfung, ob shape-ID vorhanden ist und zur agency passt (Wenn nicht, dann echo).
       elif [ ! "$(grep "$recheck" ./routes.txt | cut -d, -f2)" == "$agencyid" ]; then

        echo "Shape-ID passt nicht zur agency!"

       # Überprüfung, ob shape-ID zur Routennummer passt (Wenn nicht, dann echo).
       elif [ ! "$(grep "$recheck" ./routes.txt | sed 's/^[^,]*,[^,]*,\"\([^\"]*\)\"[^,]*,.*/\1/')" == "$OPTARG" ]; then

        echo "Routennummer passt nicht zur shape_id!"

       else

        # Die etwas umständlicheren sed-Befehle sind der Tatsache geschuldet, das einige Felder die gequotet sind, Feldtrenner (Kommas) enthalten und das Ergebnis mit cut verfälscht werden würde.

        unset abfahrtstart
        echo "Routenvariante ${shapeid}:" | tee -a ./analysis.tmp

        # uniq -f: Das Feld wird nicht ausgewertet.
        shapeidwithtrip="$(sed -n '/^[^,]*,[^,]*,[^,]*,\"[^\"]*\"[^,]*,\"[^\"]*\"[^,]*,[^,]*,[^,]*,'"$shapeid"',[^,]*,.*$/p' ./trips.txt | sed 's/^[^,]*,[^,]*,\([^,]*\),\"[^\"]*\"[^,]*,\"[^\"]*\"[^,]*,[^,]*,[^,]*,\([^,]*\),[^,]*,.*$/\1,\2/' | uniq -f 1)"
        tripid="$(echo "$shapeidwithtrip" | grep "$shapeid" | cut -d, -f1 )"
        trip="$(grep "$tripid" ./stop_times.txt)"
        serviceid="$(grep "$tripid" ./trips.txt | cut -d, -f2)"
 
        anzstopsinroute="$(echo "$trip" | wc -l)"
        for ((b=1 ; b<=(("$anzstopsinroute")) ; b++)); do
         stopline="$(echo "$trip" | sed -n ''$b'p')"
         # Es wird nur die Zeit der ersten Haltestelle benötigt. Da Variable zu Beginn leer (unset;siehe oben), wird sie beim ersten Fund neu belegt und bleibt bestehen bis zum Ende der for-Schleife.
         if [ -z "$abfahrtstart" ]; then
          abfahrtstart="$(echo "$stopline" | cut -d, -f3 | sed 's/24\(:..:..\)/00\1/')"
         fi
         haltestellenid="$(echo "$stopline" | cut -d, -f4)"
         haltestelle="$(grep "$haltestellenid" ./stops.txt | sed 's/^[^,]*,[^,]*,\"\([^\"]*\)\".*$/\1/')"

         # Hier werden die erste und letzte Zeile angezeigt und in .tmp-Datei geschrieben.
         # Zwischenhalte werden nur in Datei geschrieben
         if [ "$b" == "1" ]; then
          echo "Stop ${b}: $haltestelle" | tee -a ./analysis.tmp
         elif [ "$b" == "$anzstopsinroute" ]; then
          echo "Stop ${b}: $haltestelle" | tee -a ./analysis.tmp
          # Wird nur zur Auswertung bei der letzten Haltestelle benötigt.
          # für die Ausgaben: "Dauer der Fahrt" und "Ausgewertete Trip-ID".
          # Mit sed wird Datumsformat der Stunden von 24 Uhr auf 00 Uhr geändert, sonst passt Ergebnis nicht.
          ankunftundende="$(echo "$stopline" | cut -d, -f2 | sed 's/24\(:..:..\)/00\1/')"
         else
          echo "Stop ${b}: $haltestelle" >>./analysis.tmp
         fi
        done

        verkehrstage="$(grep '^'"$serviceid"',' ./calendar.txt | cut -d, -f2-8 | sed 's/,/ /g;s/1/x/g;s/0/-/g')"
        verkehrst_plus="$(grep '^'"$serviceid"',' ./calendar_dates.txt | grep '^.*,.*,1' | sed 's/^[^,]*,\([^,]*\),1/\1/;s/\(....\)\(..\)\(..\)/\1-\2-\3/')"
        verkehrst_minus="$(grep '^'"$serviceid"',' ./calendar_dates.txt | grep '^.*,.*,2' | sed 's/^[^,]*,\([^,]*\),2/\1/;s/\(....\)\(..\)\(..\)/\1-\2-\3/')"
        echo "Augewertete Trip-ID: $tripid (${abfahrtstart} Uhr - ${ankunftundende} Uhr)" | tee -a ./analysis.tmp
        echo "Verkehrstage des ausgewerteten Trips (Mo-So): $verkehrstage" | tee -a ./analysis.tmp
        if [ -n "$verkehrst_plus" ]; then
         echo "Zusätzliche Verkehrstage:" | tee -a ./analysis.tmp
         echo "$verkehrst_plus" | sort | tee -a ./analysis.tmp
        fi
        if [ -n "$verkehrst_minus" ]; then
         echo "Fährt nicht an diesen Tagen:" | tee -a ./analysis.tmp
         echo "$verkehrst_minus" | sort | tee -a ./analysis.tmp
        fi

        # Auswertungen für Ausgabe "Dauer der Fahrt".
        Startdate=$(date -u -d "$abfahrtstart" +"%s")
        Finaldate=$(date -u -d "$ankunftundende" +"%s")

        echo "Dauer der Fahrt: $(date -u -d "0 $Finaldate sec - $Startdate sec" +%H:%M)"  | tee -a ./analysis.tmp
        echo "Service-ID: $serviceid" | tee -a ./analysis.tmp
        echo "Haltestellen in Route: $anzstopsinroute" | tee -a ./analysis.tmp
        echo "***************************************" | tee -a ./analysis.tmp

        mv ./analysis.tmp ./results/`date +%Y%m%d_%H%M%S`_shapesingle_"$shapeid".txt

       # Ende der Verzweigung: Überprüfung der shape-ID
       fi

      else echo "Es wurde keine Route ${OPTARG} des Verkehrsunternehmens (agency) ${agencyname} gefunden. Um eine Liste aller Routen eines Verkehrsunternehmens zu erhalten, kann dieses Skript mit der Option -r aufgerufen werden."
      fi
      # ** shapesingle Ende **

  # ** Ermittlung aller Routenvarianten **
  else

     # route_id ermitteln
     routeid="$(cut -d, -f1,2,3 ./routes.txt | grep '^.*,'$agencyid',\"'$OPTARG'\"' | cut -d, -f1)"

    if [ -n "$routeid" ]; then

     tripidlist="$(grep "$routeid" ./trips.txt | cut -d, -f3)"
     # Auf cut wird verzichtet, weil in den Haltestellennamen oft ein Komma vorkommt und dann das Ergebnis verfälscht wird.
     shapeidlist="$(grep "$routeid" ./trips.txt | sed 's/^[^,]*,[^,]*,[^,]*,\"[^\"]*\"[^,]*,\"[^\"]*\"[^,]*,[^,]*,[^,]*,\([^,]*\),[^,]*,.*$/\1/' | sort | uniq)"

     echo ""
     echo "*** Ermittlung von Routenvarianten ****" | tee ./analysis.tmp
     anzshapeid="$(echo "$shapeidlist" | wc -l)"
     echo "Ausgewertete Route: $OPTARG" | tee -a ./analysis.tmp
     echo "Operator (agency): $agencyname" | tee -a ./analysis.tmp
     echo "$anzshapeid Fahrtvarianten gefunden (shape_id):" | tee -a ./analysis.tmp
     echo $shapeidlist | tee -a ./analysis.tmp
     echo "***************************************" | tee -a ./analysis.tmp

     # In dieser Schleife wird die shape_id ermittelt und EINE dazugehörige trip_id ermittelt, weil nicht jeder einzelne Trip ausgewertet werden soll. Die etwas umständlicheren sed-Befehle sind der Tatsache geschuldet, das einige Felder die gequotet sind, Feldtrenner (Kommas) enthalten und das Ergebnis mit cut verfälscht werden würde.
     for ((c=1 ; c<=(("$anzshapeid")) ; c++)); do

      unset abfahrtstart
      echo "Routenvariante ${c}:" | tee -a ./analysis.tmp

      shapeid="$(echo "$shapeidlist" | sed -n ''$c'p')"
      # uniq -f: Das Feld wird nicht ausgewertet.
      shapeidwithtrip="$(sed -n '/^[^,]*,[^,]*,[^,]*,\"[^\"]*\"[^,]*,\"[^\"]*\"[^,]*,[^,]*,[^,]*,'"$shapeid"',[^,]*,.*$/p' ./trips.txt | sed 's/^[^,]*,[^,]*,\([^,]*\),\"[^\"]*\"[^,]*,\"[^\"]*\"[^,]*,[^,]*,[^,]*,\([^,]*\),[^,]*,.*$/\1,\2/' | uniq -f 1)"
      tripid="$(echo "$shapeidwithtrip" | grep "$shapeid" | cut -d, -f1 )"
      trip="$(grep "$tripid" ./stop_times.txt)"
      serviceid="$(grep "$tripid" ./trips.txt | cut -d, -f2)"
 
      anzstopsinroute="$(echo "$trip" | wc -l)"
      for ((b=1 ; b<=(("$anzstopsinroute")) ; b++)); do
       stopline="$(echo "$trip" | sed -n ''$b'p')"
       # Es wird nur die Zeit der ersten Haltestelle benötigt. Da Variable zu Beginn leer (unset;siehe oben), wird sie beim ersten Fund neu belegt und bleibt bestehen bis zum Ende der for-Schleife.
       if [ -z "$abfahrtstart" ]; then
        abfahrtstart="$(echo "$stopline" | cut -d, -f3 | sed 's/24\(:..:..\)/00\1/')"
       fi
       haltestellenid="$(echo "$stopline" | cut -d, -f4)"
       haltestelle="$(grep "$haltestellenid" ./stops.txt | sed 's/^[^,]*,[^,]*,\"\([^\"]*\)\".*$/\1/')"

       # Hier werden die erste und letzte Zeile angezeigt und in .tmp-Datei geschrieben.
       # Zwischenhalte werden nur in Datei geschrieben
       if [ "$b" == "1" ]; then
        echo "Stop ${b}: $haltestelle" | tee -a ./analysis.tmp
       elif [ "$b" == "$anzstopsinroute" ]; then
        echo "Stop ${b}: $haltestelle" | tee -a ./analysis.tmp
        # Wird nur zur Auswertung bei der letzten Haltestelle benötigt.
        # für die Ausgaben: "Dauer der Fahrt" und "Ausgewertete Trip-ID".
        # Mit sed wird Datumsformat der Stunden von 24 Uhr auf 00 Uhr geändert, sonst passt Ergebnis nicht.
        ankunftundende="$(echo "$stopline" | cut -d, -f2 | sed 's/24\(:..:..\)/00\1/')"
       else
        echo "Stop ${b}: $haltestelle" >>./analysis.tmp
       fi
      done

      verkehrstage="$(grep '^'"$serviceid"',' ./calendar.txt | cut -d, -f2-8 | sed 's/,/ /g;s/1/x/g;s/0/-/g')"
      verkehrst_plus="$(grep '^'"$serviceid"',' ./calendar_dates.txt | grep '^.*,.*,1' | sed 's/^[^,]*,\([^,]*\),1/\1/;s/\(....\)\(..\)\(..\)/\1-\2-\3/')"
      verkehrst_minus="$(grep '^'"$serviceid"',' ./calendar_dates.txt | grep '^.*,.*,2' | sed 's/^[^,]*,\([^,]*\),2/\1/;s/\(....\)\(..\)\(..\)/\1-\2-\3/')"
      echo "Augewertete Trip-ID: $tripid (${abfahrtstart} Uhr - ${ankunftundende} Uhr)" | tee -a ./analysis.tmp
      echo "Verkehrstage des ausgewerteten Trips (Mo-So): $verkehrstage" | tee -a ./analysis.tmp
      if [ -n "$verkehrst_plus" ]; then
       echo "Zusätzliche Verkehrstage:" | tee -a ./analysis.tmp
       echo "$verkehrst_plus" | sort | tee -a ./analysis.tmp
      fi
      if [ -n "$verkehrst_minus" ]; then
       echo "Fährt nicht an diesen Tagen:" | tee -a ./analysis.tmp
       echo "$verkehrst_minus" | sort | tee -a ./analysis.tmp
      fi

      # Auswertungen für Ausgabe "Dauer der Fahrt".
      Startdate=$(date -u -d "$abfahrtstart" +"%s")
      Finaldate=$(date -u -d "$ankunftundende" +"%s")

      echo "Dauer der Fahrt: $(date -u -d "0 $Finaldate sec - $Startdate sec" +%H:%M)"  | tee -a ./analysis.tmp
      echo "Shape-ID: $shapeid" | tee -a ./analysis.tmp
      echo "Service-ID: $serviceid" | tee -a ./analysis.tmp
      echo "Haltestellen in Route: $anzstopsinroute" | tee -a ./analysis.tmp
      echo "***************************************" | tee -a ./analysis.tmp

     # Ende der c-Schleife
     done

     mv ./analysis.tmp ./results/`date +%Y%m%d_%H%M%S`_tripvarianten_"$agencyname".txt

    else echo "Es wurde keine Route ${OPTARG} des Verkehrsunternehmens (agency) ${agencyname} gefunden. Um eine Liste aller Routen eines Verkehrsunternehmens zu erhalten, kann dieses Skript mit der Option -r aufgerufen werden."
    fi

# Ende Verzweigung shapesingle/Alle Routenvarianten
fi

  ;;

  # *** GPX-Erstellung ***

  g) operatorabfrage
     # route_id ermitteln
     routeid="$(cut -d, -f1,2,3 ./routes.txt | grep '^.*,'$agencyid',\"'$OPTARG'\"' | cut -d, -f1)"

    if [ -n "$routeid" ]; then

     # Auf cut wird verzichtet, weil in den Haltestellennamen oft ein Komma vorkommt und dann das Ergebnis verfälscht wird.
     shapeidlist="$(grep "$routeid" ./trips.txt | sed 's/^[^,]*,[^,]*,[^,]*,\"[^\"]*\"[^,]*,\"[^\"]*\"[^,]*,[^,]*,[^,]*,\([^,]*\),[^,]*,.*$/\1/' | sort | uniq)"

     echo ""
     echo "***** Erstellung von GPX-Dateien ******" | tee ./analysis.tmp
     anzshapeid="$(echo "$shapeidlist" | wc -l)"
     echo "Ausgewertete Route: $OPTARG" | tee -a ./analysis.tmp
     echo "Operator (agency): $agencyname" | tee -a ./analysis.tmp
     echo "$anzshapeid Fahrtvarianten gefunden (shape_id):" | tee -a ./analysis.tmp
     echo $shapeidlist | tee -a ./analysis.tmp
     echo "***************************************" | tee -a ./analysis.tmp

     for ((c=1 ; c<=(("$anzshapeid")) ; c++)); do

      shapeid="$(echo "$shapeidlist" | sed -n ''$c'p')"

      echo "Generiere GPX ${c} ..."
      echo "Name der GPX-Datei: "$OPTARG"_"$shapeid".gpx"  | tee -a ./analysis.tmp

      shapelist="$(grep '^'"$shapeid"',' ./shapes.txt | sort -t"," -k4 -n | cut -d, -f2,3 | sed 's/\(^[^,]*\),\(.*\)/<trkpt lat=\"\1\" lon=\"\2\">\n<\/trkpt>/')"
      echo "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\" ?>" >./"$OPTARG"_"$shapeid".gpx
      echo "<gpx version=\"1.1\" creator=\"${0}\">" >>./"$OPTARG"_"$shapeid".gpx
      echo "<trk>" >>./"$OPTARG"_"$shapeid".gpx
      echo "<name>${OPTARG}_${shapeid}</name>" >>./"$OPTARG"_"$shapeid".gpx
      echo "<trkseg>" >>./"$OPTARG"_"$shapeid".gpx
      echo "$shapelist" >>./"$OPTARG"_"$shapeid".gpx

      # uniq -f: Das Feld wird nicht ausgewertet.
      shapeidwithtrip="$(sed -n '/^[^,]*,[^,]*,[^,]*,\"[^\"]*\"[^,]*,\"[^\"]*\"[^,]*,[^,]*,[^,]*,'"$shapeid"',[^,]*,.*$/p' ./trips.txt | sed 's/^[^,]*,[^,]*,\([^,]*\),\"[^\"]*\"[^,]*,\"[^\"]*\"[^,]*,[^,]*,[^,]*,\([^,]*\),[^,]*,.*$/\1,\2/' | uniq -f 1)"
      tripid="$(echo "$shapeidwithtrip" | grep "$shapeid" | cut -d, -f1 )"
      trip="$(grep "$tripid" ./stop_times.txt)"
      
      # Haltestellen werden als Wegepunkte in GPX-Datei geschrieben.
      anzstopsinroute="$(echo "$trip" | wc -l)"
      for ((b=1 ; b<=(("$anzstopsinroute")) ; b++)); do
       stopline="$(echo "$trip" | sed -n ''$b'p')"
       haltestellenid="$(echo "$stopline" | cut -d, -f4)"
       haltestelle="$(grep "$haltestellenid" ./stops.txt | sed 's/^[^,]*,[^,]*,\"\([^\"]*\)\".*$/\1/')"
       haltestellelatlon="$(grep "$haltestellenid" ./stops.txt | sed 's/^[^,]*,[^,]*,\"[^\"]*\"[^,]*,[^,]*,\"\([^\"]*\)\"[^,]*,\"\([^\"]*\)\"[^,]*,.*$/<wpt lat=\"\1\" lon=\"\2\">/')"
       echo "$haltestellelatlon" >>./"$OPTARG"_"$shapeid".gpx
       echo "<name>Stop ${b}: ${haltestelle}</name>" >>./"$OPTARG"_"$shapeid".gpx
       echo "</wpt>" >>./"$OPTARG"_"$shapeid".gpx
      done

      echo "</trkseg>" >>./"$OPTARG"_"$shapeid".gpx
      echo "</trk>" >>./"$OPTARG"_"$shapeid".gpx
      echo "</gpx>" >>./"$OPTARG"_"$shapeid".gpx

      triplength="$(gpxinfo ./"$OPTARG"_"$shapeid".gpx | sed -n 1,12p | grep 'Length 3D' | sed 's/.*Length 3D: \(.*\)/\1/')"

      echo "Shape-ID: $shapeid" | tee -a ./analysis.tmp
      echo "Länge der Route: ${triplength}" | tee -a ./analysis.tmp
      echo "Haltestellen in Route: $anzstopsinroute" | tee -a ./analysis.tmp
      echo "***************************************" | tee -a ./analysis.tmp

 
      mv ./"$OPTARG"_"$shapeid".gpx ./gpx/

     # Ende der c-Schleife
     done

     mv ./analysis.tmp ./results/`date +%Y%m%d_%H%M%S`_generategpx_"$agencyname".txt

    else echo "Es wurde keine Route ${OPTARG} des Verkehrsunternehmens (agency) ${agencyname} gefunden. Um eine Liste aller Routen eines Verkehrsunternehmens zu erhalten, kann dieses Skript mit der Option -r aufgerufen werden."
    fi

  ;;

  l) if [ "$OPTARG" == "routes" ]; then
      operatorabfrage
      routeidlist="$(grep '^.*,'"$agencyid"',' ./routes.txt | cut -d, -f1)"

      allerouten="$(cut -d, -f1,2,3 ./routes.txt | grep '^.*,'$agencyid',' | cut -d, -f3 | sed 's/\"\(.*\)\"/\1/' | sort -n)"

      zusammenfassung1() {
       echo "********************** Liste der Routen ***********************"
       echo "Verkehrsunternehmen (agency): ${agencyname}"
       # sed '/^$/d' löscht alle Leerzeilen, die manchmal das Ergebnis verfälschen würden.
       echo "Es wurden $(echo "${allerouten}" | sed '/^$/d' | wc -l) Routen gefunden."
       echo "***************************************************************"
      }

      zusammenfassung1 >./gtfsroutelist.tmp
      echo "$allerouten" | tee -a ./gtfsroutelist.tmp 
      zusammenfassung1
      echo ""

      mv ./gtfsroutelist.tmp ./results/`date +%Y%m%d_%H%M%S`_gtfsroutelist_"$agencyname".txt

     fi

     if [ "$OPTARG" == "stops" ]; then
  
      # **** Hier werden alle Haltestellen einer bestimmten agency ermittelt. ****
      operatorabfrage

      echo ""
      echo "Die Ermittlung der Haltestellen kann mehrere Minuten dauern ..."
      echo ""

      # Hier wird zunächst die route_id ermittelt und dann trips.txt nach der route_id durchsucht. 
      # Dann werden die Felder 1 (route_id), 3 (trip_id) und 8 (shape_id) selektiert.
      # Es werden doppelte shape_id's ignoriert und die entsprechenden trip_ids ermittelt.
      # Dann wird alles in die Datei tripidlist.tmp geschrieben.
      routeidlist="$(grep '^.*,'"$agencyid"',' ./routes.txt | cut -d, -f1)"
      anzrouteid="$(echo "$routeidlist" | wc -l)"
      for ((x=1 ; x<=(("$anzrouteid")) ; x++)); do
       routeid="$(echo "$routeidlist" | sed -n ''$x'p')"
       grep '^'"$routeid"',' ./trips.txt | sed 's/\(^[^,]*\),[^,]*,\([^,]*\),\"[^\"]*\"[^,]*,\"[^\"]*\"[^,]*,[^,]*,[^,]*,\([^,]*\),[^,]*,.*$/\1,\2,\3/' | uniq -f 2 | cut -d, -f2 >>./tripidlist.tmp
      done

      # Hier werden die stop_id's aus der Datei stop_times.txt ermittelt.
      anztripid="$(cat ./tripidlist.tmp | wc -l)"
      for ((y=1 ; y<=(("$anztripid")) ; y++)); do
       tripid="$(cat ./tripidlist.tmp | sed -n ''$y'p')"
       grep '^'"$tripid"',' ./stop_times.txt | cut -d, -f4 >>./stopidlist.tmp
      done

      # Anhand der stopidlist.tmp werden dann die Haltestellennamen aus der der Datei stops.txt ermittelt.
      # Hier könnte man bei Bedarf auch noch weitere Informationen (stop_id, lon, lat) in die Ausgabe schreiben.
      anzstopid="$(cat ./stopidlist.tmp | wc -l)"
      for ((z=1 ; z<=(("$anzstopid")) ; z++)); do
       echo "Stop_id ${z}/${anzstopid} wird bearbeitet ..."
       stopid="$(cat ./stopidlist.tmp | sort | uniq | sed -n ''$z'p')"
       grep '^'"$stopid"',' ./stops.txt | sed 's/^[^,]*,\"[^\"]*\"[^,]*,\"\([^\"]*\)\"[^,]*,.*$/\1/' >>./allehaltestellen.tmp
      done
      echo ""

      allestops="$(cat ./allehaltestellen.tmp | sort)"
    
      zusammenfassung2() {
       echo "******************* Liste der Haltestellen ********************"
       echo "Verkehrsunternehmen (agency): ${agencyname}"
       # sed '/^$/d' löscht alle Leerzeilen, die manchmal das Ergebnis verfälschen würden.
       echo "Es wurden $(echo "${allestops}" | sed '/^$/d' | wc -l) Haltestellen gefunden." 
       echo "***************************************************************"
      }

      zusammenfassung2 >./gtfsstoplist.tmp
      echo "$allestops" | tee -a ./gtfsstoplist.tmp 
      zusammenfassung2
      echo ""

      mv ./gtfsstoplist.tmp ./results/`date +%Y%m%d_%H%M%S`_gtfsstoplist_"$agencyname".txt

      rm -f ./tripidlist.tmp
      rm -f ./stopidlist.tmp
      rm -f ./allehaltestellen.tmp

     fi

     # Hier werden alle vorhandenen Haltestellen in den GTFS-Daten ermittelt.
     if [ "$OPTARG" == "allstops" ]; then
      cat ./stops.txt | sed 's/^[^,]*,\"[^\"]*\"[^,]*,\"\([^\"]*\)\"[^,]*,.*$/\1/' | sort >./gtfsallstoplist.tmp
      
      # attributions.txt auslesen
      echo ""
      echo "Es wurden $(cat ./gtfsallstoplist.tmp | sed '/^$/d' | wc -l) Haltestellen gezählt."
      echo "Die Liste kann eingesehen werden in ${PWD}/results/*_gtfsallstoplist.txt"
      echo ""

      mv ./gtfsallstoplist.tmp ./results/`date +%Y%m%d_%H%M%S`_gtfsallstoplist.txt

     fi

  ;;

  # Hier weitere Optionen

 esac

# Ende der getopts-Schleife
done

# Aufräumen
rm -f ./verzweigung.tmp
rm -f ./routesandtrips.tmp

