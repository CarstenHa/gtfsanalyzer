# gtfsanalyzer

Bash-Skript zum Analysieren von GTFS-Daten (Soll-Fahrplandaten). 

Das Programm ist eine Beta-Version und wertet nicht den kompletten Umfang der GTFS-Daten aus. Es kann auch zur fehlerhaften Ausgabe kommen (z.B. durch unterschiedliches Quoting in den GTFS-Dateien etc.). Dann kann das Programm mit der Option -f aufgerufen werden. Dann werden die GTFS-Dateien gecheckt und ggf. entsprechend angepasst. Dadurch können eventuell schon einige Probleme gelöst werden. Die Originaldateien werden zwar im Unterordner 'backup' gesichert, aber es kann nicht schaden, vorher zusätzlich ein Datenbackup durchzuführen.

Mehrere Optionen stehen zur Verfügung. So können zum Beispiel:

* Alle Trips einer bestimmten Route aus den Daten gelesen werden. 
* Fahrtvarianten einer bestimmten Route ausgewertet werden.
* GPX-Dateien zu den Fahrtvarianten einer bestimmten Route erstellt werden.
* Eine Gruppe von Haltestellen ausgewertet werden (inkl. Erstellung von GPX-Dateien).
* Routen oder Haltestellen einer bestimmten agency angezeigt werden. Oder alle Haltestellen aus den GTFS-Daten ausgelesen werden.
* Alle Trips einer Route mit Haltestellen und Abfahrtszeiten in einer HTML-Seite angezeigt werden.

Das Programm muss in einem Ordner mit GTFS-Daten ausgeführt werden. Zur vollen Funktionalität wird außerdem das Programm gpxinfo (zum Beispiel aus dem Paket python3-gpxpy) benötigt.

Eine ausführliche Hilfe erhalten Sie mit der Option -h

Viel Spass!
