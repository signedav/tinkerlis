# TINKERLIS oder wie verheirate ich QField mit INTERLIS

## Problem

### QField ... 

#### ... und FKs

FKs in QField Projekten funktionieren nicht, weil die Synchronisierung keine Reihenfolge bzw. Transaktion berücksichtigt. Dies zu implementieren ist schwierig. Die empfohlene Lösung sind "lose" Relations in QGIS.

Ivan sagt zwar:
> depends on the order they are inserted in QGIS. If the parent is first and then the children, it should work fine. I think that is the case.

Aber ich denke das wollen wir uns nicht antun.

### ... und Serials

Serials führen mit QField (wie in jedem Fall von "mergen" mehrerer Datensätze) zu Probleme. Deshalb werden (wie ja auch in INTERLIS) systemübergreifende UUIDs als Ids/Referenzen empfohlen.

## INTERLIS/ili2db ...

### ... und FKs

Es kann auf FK Constraint Erstellung verzichtet werden (entferne `--createFK`), die benötigten Spalten werden dennoch erzeugt.

Es müssen dann aber QGIS Relations ***manuell*** erstellt werden.

### ... und Serials

ili2db erstellt technische T_Ids (serials) als PKs/FKs.

OIDs (t_ili_tids) könnte UUIDs sein, aber die werden mit ili2db nicht als "echte" PKs/FKs verwendet, und dafür werden auch keine FK-Felder in den Child Tables erstellt. In einer Korrespondenz mit Claude begründete er, dies:

> alles was du aufzählst war nicht der Hauptgrund.
> 
> Die Hauptgründe waren:
> 
> 1) Damit es einheitlich ist. Strukturen haben ja im ili gar keine ID, aber in der DB schon. Aber auch Klassen müssen nicht zwingend die selbe Art OID haben. Ich wollte in der DB als PK/FK aber nur eine Art haben (eben einheitlich nur long's; unabhängig vom ili-Model). 
> 2) Damit man das ili-Modell ändern kann, und in der der DB die PK/FKs nicht ändern muss, sondern eben nur die t_ili_id. Also dass man einfacher auf neue ili-Modellversionen migrieren kann.

(zusätzlich zu meinen Annahmen, weshalb das so ist):

> Meine Annahme und folglich Antwort ist, weil erstens diese OID nicht unbedingt auf der Datenbank automatisch generiert werden kann (es sei denn es ist eine UUID) und zweitens weil eine numerische T_Id performanter ist. Ausserdem könnte die Datenbank nicht funktionieren, falls die OIDs nicht stabil sind (was sie ja nicht immer sein müssen - je nach Modell). Gibt es weitere Punkte? Oder würde sogar ein Parameter --useOidAsTid Sinn machen?

Ich bemerkte also:

> Aber die Frage, ob als T_Id die OID genommen werden kann, wäre da sowieso falsch. Wenn schon, würde es lauten, ob auf Plattformen, die UUIDs generieren können, die T_Id anstatt einer long-serials azcg eine UUID sein könnte.

Und darauf meinte Claude:

> das wäre sicher schon machbar, aber aufwändig.
>
> Das Aufwändige ist, dass die UUID nicht auf allen Platformen gleich funktioniert. D.h. ich müsste nicht nur bei allen SQL Statements zwischen Long und UUID unterscheiden, sondern auch noch je nach Platform einen anderen Wrapper nutzen.
>
> Wie gesagt: machbar, aber nicht mit wenig Aufwand.

## Lösungsansätze

Wir brauche UUIDs, die wir in QField als Referenz nehmen können.

### ili2db Improvement
Wir fragen Claude, dass er UUIDs als T_Ids anbieten kann (e.g. `--createUUIDsAsTids`).

#### Pros
- Schema erstellen und Projekt mit Model Baker out of the box funktioniert in QField

#### Cons
- Aufwändig und die Lösung wird nicht so bald zur Verfügung stehen

### Postscript

Wir erstellen ein Schema mit ili2db, entfernen `--createFK` und führen ein Postscript aus (Beispiel von unten):

```
ALTER TABLE uuid_test1.gebaeude
ALTER COLUMN besitzerin TYPE uuid;

ALTER TABLE uuid_test1.gebaeude
ALTER COLUMN t_id TYPE uuid;

ALTER TABLE uuid_test1.gebaeude
ALTER COLUMN t_id SET DEFAULT uuid_generate_v4();

ALTER TABLE uuid_test1.besitzerin
ALTER COLUMN t_id TYPE uuid;

ALTER TABLE uuid_test1.besitzerin
ALTER COLUMN t_id SET DEFAULT uuid_generate_v4();
```

Dies konnte kein Projekt mit Model Baker erstellen. Ich müsste da weiter investieren.

#### Pros
- QField lauffähiges Projekt

#### Cons
- Dragons! Keine Ahnung ob das dann mit ili2db Export einwandfrei läuft.
- Model Baker muss angepasst werden

### Extended Model mit OID_FK Attribut + Script 

Erweitern des modells um "pseudo" FK Spalten die dann mit den t_ili_tids der Parent-Layer verknüpft werden + ein Script, dass die "echten" FK Spalten mit den betr. T_Ids befüllt...

```
CLASS Gebaeude (EXTENDED) =
    Besitzerin_OID : MANDATORY TEXT*99;
END Gebaeude;
```

Config your own relations and then have a script.

With field calculator:

```
attribute(get_feature('BesitzerIn','t_ili_tid',besitzerin_oid),'t_id')
```

Or with PyQGIS (WIP):
```python
rel_man=QgsRelationManager(QgsProject.instance())
besitzerin_oid_rel = rel_man.relationsByName('besitzerin_oid')[0]
child = besitzerin_oid_rel.referencingLayer()
parent = besitzerin_oid_rel.referencedLayer()

fk_oid_index = child.fields().indexFromName('besitzerin_oid')
fk_index = child.fields().indexFromName('besitzerin')
oid_index = parent.fields().indexFromName('t_ili_tid')
pk_index = parent.fields().indexFromName('t_id')

for feature in child.getFeatures():
    feature[field_index] = 'new_value' # set the new value for the field
    layer.updateFeature(feature)
```

#### Pros
- Meiner Meinung nach stabil

#### Cons
- Es ist echtes TINKERLIS
- Es braucht ein Script (Funktion / Modell / Plugin / whatever) in QGIS

### Vollintegration von ili2db in QField

Natürlich könnte man auch eine Vollintegration andenken mit Basket-Päckchen für jedes einzelne Gerät und die Zusammenfügung der Daten mit ili2db machen. INTERLIS ist ja dafür gemacht. Doch das ist aufwändig und auch hier erwarte ich Drachen...

## Beispielmodelle

```
INTERLIS 2.3;

/* Ortsplanung as national model importing the infrastrukture used for using geometry types and connectiong to strasse */
MODEL Ortsplanung_V1_1 (en) AT "https://modelbaker.ch" VERSION "2023-03-29" =
  TOPIC Konstruktionen =

    CLASS Gebaeude  =
      Name : MANDATORY TEXT*99;
    END Gebaeude;

    CLASS BesitzerIn =
      Vorname : MANDATORY TEXT*99;
      Nachname : MANDATORY TEXT*99;
    END BesitzerIn;

    ASSOCIATION Gebaeude_BesitzerIn =
      BesitzerIn -- {0..1} BesitzerIn;
      Gebaeude -- {0..*} Gebaeude;
    END Gebaeude_BesitzerIn;

  END Konstruktionen;

END Ortsplanung_V1_1.
```

```
INTERLIS 2.3;

/* Ortsplanung as national model importing the infrastrukture used for using geometry types and connectiong to strasse */
MODEL QFieldOrtsplanung_V1_1 (en) AT "https://modelbaker.ch" VERSION "2023-03-29" =
  IMPORTS Ortsplanung_V1_1;

  TOPIC Konstruktionen EXTENDS Ortsplanung_V1_1.Konstruktionen=

    CLASS Gebaeude (EXTENDED) =
      Besitzerin_OID : MANDATORY TEXT*99;
    END Gebaeude;

  END Konstruktionen;

END QFieldOrtsplanung_V1_1.
```