#!/bin/sh

LOGFILE=/tmp/currentPageUpdateLog.txt
KRDB=/mnt/ext1/applications/koreader/settings/statistics.sqlite3
PBDB=/mnt/ext1/system/explorer-3/explorer-3.db

#cd /mnt/ext1/applications
echo "Starting page update `date`" > $LOGFILE
errorMsg=""
currentPlaceInCode=""

insertPbBookSettingsRec () {
  echo "Inserting into PB Book Settings" >> $LOGFILE
  echo "INSERT INTO BOOKS_SETTINGS (BOOKID,PROFILEID,CPAGE,NPAGE,OPENTIME) VALUES ($pbBookID,1,$currentPageNum,$totalPageCount,$currentTimeStamp);" >> $LOGFILE
  currentTimeStamp=$(date +%s)
  sqlite3 $PBDB "INSERT INTO BOOKS_SETTINGS (BOOKID,PROFILEID,CPAGE,NPAGE,OPENTIME) VALUES (\""$pbBookID"\",1,\""$currentPageNum"\",\""$totalPageCount"\",\""$currentTimeStamp"\");" 2>> $LOGFILE || currentPlaceInCode="Inserting PocketBook settings record" checkError
}

updatePbBookSettingsRec () {
  echo "Updating PB Book Settings record" >> $LOGFILE
  echo "UPDATE BOOKS_SETTINGS SET CPAGE =$currentPageNum,NPAGE=$totalPageCount WHERE BOOKID=$pbBookID;" >> $LOGFILE
  sqlite3 $PBDB "UPDATE BOOKS_SETTINGS SET CPAGE =\""$currentPageNum"\",NPAGE=\""$totalPageCount"\" WHERE BOOKID=\""$pbBookID"\";" 2>> $LOGFILE || currentPlaceInCode="Updating PocketBook settings record" checkError
}

checkError (){
  exitScript=$1
  
  if [ $exitScript = "true" ]; then
    someKindOfError=$(tail -n 1 $LOGFILE)
    dialog 1 "" "Error detected at $currentPlaceInCode. Error is $someKindOfError" "OK"
    exit
  fi 

  if [ $? -eq 0 ]; then
    sqlError=$(tail -n 1 $LOGFILE)
    dialog 1 "" "Error detected at $currentPlaceInCode.Error is $sqlError" "OK"   
    exit
  fi
}


koReaderBookID=$(sqlite3 $KRDB "SELECT ID FROM BOOK ORDER BY LAST_OPEN DESC LIMIT 1;") 2>> $LOGFILE || currentPlaceInCode="Get KoReader book Id" checkError
echo "SELECT ID FROM BOOK ORDER BY LAST_OPEN DESC LIMIT 1;" >> $LOGFILE
echo "KoReader book id: $koReaderBookID" >> $LOGFILE

totalPageCount=$(sqlite3 $KRDB "SELECT TOTAL_PAGES FROM PAGE_STAT_DATA WHERE ID_BOOK=$koReaderBookID ORDER BY START_TIME DESC LIMIT 1;") 2>> $LOGFILE || currentPlaceInCode="Getting total pages from KoReader" checkError
echo "SELECT TOTAL_PAGES FROM PAGE_STAT_DATA WHERE ID_BOOK=$koReaderBookID ORDER BY START_TIME DESC LIMIT 1;" >> $LOGFILE
echo "KoReader Total Page Count: $totalPageCount" >> $LOGFILE

currentPageNum=$(sqlite3 $KRDB "SELECT PAGE FROM PAGE_STAT_DATA WHERE ID_BOOK=\""$koReaderBookID"\" ORDER BY START_TIME DESC LIMIT 1;") 2>> $LOGFILE || currentPlaceInCode="Getting current page from KoReader" checkError
echo "SELECT PAGE FROM PAGE_STAT_DATA WHERE START_TIME=(SELECT MAX(START_TIME) FROM PAGE_STAT_DATA WHERE ID_BOOK=$koReaderBookID" >> $LOGFILE
echo "KoReader Current Page Number $currentPageNum" >> $LOGFILE

currentBookTitle=$(sqlite3 $KRDB "SELECT TITLE FROM BOOK WHERE ID=\""$koReaderBookID"\";") 2>>$LOGFILE || currentPlaceInCode="Getting current book title from KoReader" checkError
echo "SELECT TITLE FROM BOOK WHERE ID_BOOK=\""$koReaderBookID"\";" >> $LOGFILE
echo "KoReader Current Book Title $currentBookTitle" >> $LOGFILE

pbBookID=$(sqlite3 $PBDB "SELECT ID FROM BOOKS_IMPL WHERE TRIM(UPPER(TITLE))=TRIM(UPPER('$currentBookTitle'));") 2>> $LOGFILE || currentPlaceInCode="Getting pocketbook book ID" checkError 
echo "SELECT ID FROM BOOKS_IMPL WHERE TRIM(UPPER(TITLE))=TRIM(UPPER($currentBookTitle));" >> $LOGFILE
echo "PocketBook ID: $pbBookID" >> $LOGFILE

if [ -z "$pbBookID" ];
then
        echo "No Pocket Book ID found in books_impl" >> $LOGFILE
	currentPlaceInCode="No PocketBook ID found in books_impl"
	checkError true
fi

recordInPbBookSettings=$(sqlite3 $PBDB "SELECT BOOKID FROM BOOKS_SETTINGS WHERE BOOKID = \""$pbBookID"\";") 2>> $LOGFILE || currentPlaceInCode="Getting pocketbook book settings record" checkError
echo "Record in PocketBook Settings Table: $recordInPbBookSettings" >> $LOGFILE

if [ "$recordInPbBookSettings" =  "" ];
then
  insertPbBookSettingsRec
  currentPlaceInCode="Inserting record to PocketBook Settings table"
  dialog 1 "" "Inserted record for Book Title: $currentBookTitle, Book ID: $pbBookID, Current Page: $currentPageNum, Of Total Pages $totalPageCount" "OK"
else
  updatePbBookSettingsRec
  currentPlaceInCode="Updating value in PocketBook Book Settings Table"
  dialog 1 "" "Updated record for Book Title: $currentBookTitle, Book ID: $pbBookID, Current Page: $currentPageNum, Of Total Pages $totalPageCount" "OK"
fi
