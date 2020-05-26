import strutils, db_sqlite, kaiser, json, sequtils, times, os, rdstdin

var db: DbConn
const NJVERSION = "0.2.0"

proc searchJournal(s:string)=
    var q = "SELECT * FROM journal WHERE title like '"&s&"'"
    for x in db.fastRows(sql(q)):
        echo "== ("+x[0]+") " + x[1] + " =="
        echo x[2]
        echo "@ "+x[5]
        echo x[4].split(":").join(" - ")
        echo "Mood: " + x[3]
        echo "----"
        
proc searchJournalByID(s:string)=
    var q = "SELECT * FROM journal WHERE id = '"&s&"'"
    for x in db.fastRows(sql(q)):
        echo "== ("+x[0]+") " + x[1] + " =="
        echo x[2]
        echo "@ "+x[5]
        echo x[4].split(":").join(" - ")
        echo "Mood: " + x[3]
        echo "----"
        
proc searchJournalByMood(s:string)=
    var q = "SELECT * FROM journal WHERE mood = '"&s&"'"
    for x in db.fastRows(sql(q)):
        echo "== ("+x[0]+") " + x[1] + " =="
        echo x[2]
        echo "@ "+x[5]
        echo x[4].split(":").join(" - ")
        echo "Mood: " + x[3]
        echo "----"
        
proc searchJournalByTag(s:seq[string])=
    var q = "SELECT * FROM journal"
    for x in db.fastRows(sql(q)):
        var send = false
        for tag in s:
            if tag in x[4].split(":"):
                send = true

        if send:
            echo "== ("+x[0]+") " + x[1] + " =="
            echo x[2]
            echo "@ "+x[5]
            echo x[4].split(":").join(" - ")
            echo "Mood: " + x[3]
            echo "----"
            
proc deleteEntry(s:seq[string])=
    for id in s:
        var q = "SELECT * FROM journal WHERE id = '"&id&"'"
        for x in db.fastRows(sql(q)):
            echo "== ("+x[0]+") " + x[1] + " =="
            echo x[2]
            echo "@ "+x[5]
            echo x[4].split(":").join(" - ")
            echo "Mood: " + x[3]
            echo "----"
            echo "Delete this entry? (y/n)"
            let input = readLineFromStdin("> ")
            if input == "y":
                echo "Deleting."
                var q = "DELETE FROM journal WHERE id = '"&id&"'"
                db.exec(sql(q))
            else:
                echo "Cancelling."
            
proc writeToJournal(s:var seq[string])=
    var
        mood, title, body:string
        tags, b:seq[string]
    b = s.copy()
    var id = 0
    try:
        for x in db.fastRows(sql"SELECT * FROM journal ORDER by id DESC"):
            if parseInt(x[0]) >= id:
                id = parseInt(x[0])+1
    except:
        echo "Default ID.."
    echo id
    if "::" in b:
        for w in b:
            discard s.shift()
            if w == "::":
                break
            title = title + " " + w
            
    title = title.strip()        

    for word in b:
        if word.startsWith("m:"):
            mood = word.split(":")[1]
            s - word
            
        if word.startsWith("t:"):
            tags.add(word.split(":")[1])
            s - word
            
    body = s.join(" ")
    echo "title; "+title
    echo "mood; "+mood
    echo "tags; "+tags.join(", ")
    echo "body; "+body
    let timestamp = getTime()
    echo timestamp
    if not db.tryExec(sql"insert into journal (id, title, body, mood, tags, timestamp) values (?, ?, ?, ?, ?, ?)",
                      id, title, body, mood, tags.join(":"), timestamp):
        db.exec(sql"create table journal (id, title, body, mood, tags, timestamp)")
        if not db.tryExec(sql"insert into journal (id, title, body, mood, tags, timestamp) values (?, ?, ?, ?, ?, ?)",
                          id, title, body, mood, tags.join(":"), timestamp):
            echo "Failed to insert... "
            dbError(db)
            
proc main()=
    var a = parseArgTable()
    var args = a[":args"].getElems().toStrArray()

    if args.len == 0:
        args = @["shell"]
        
    let command = args.shift()
    
    #echo args
    
    case command
    of "help", "h":
        echo "Journal "+NJVERSION
        echo "$ write/w [title ::] <message> [t:tag] [t:othertag] [m:mood]"
        echo "                  ^ seperator for splitting title from message"
        echo "$ delete/del/d <... id list>"
        echo "$ find/f <search title>"
        echo "$ tagged/t <search tags>"
        echo "$ get/g <id>"
        echo "$ mood/m <mood>"
        echo "$ ls/list"
        echo ""
        echo "ENV"
        echo "Change these environment variables to desired effects."
        echo "NJ_DEFAULT_ORDER = ASC/DESC - Changes the list command order."
    of "write", "w":
        args.writeToJournal
    of "del", "delete", "d":
        args.deleteEntry
    of "find", "f":
        args.join(" ").searchJournal
    of "tagged", "t":
        args.searchJournalByTag
    of "get", "g":
        args.join(" ").searchJournalByID
    of "mood", "m":
        args.join(" ").searchJournalByMood
    of "ls", "list":
        var order = getEnv("NJ_DEFAULT_ORDER", "DESC")
        let s = "SELECT * FROM journal ORDER by id "+order
        for x in db.fastRows(s.sql):
            echo "== ("+x[0]+") " + x[1] + " =="
            echo x[2]
            echo "@ "+x[5]
            echo x[4].split(":").join(" - ")
            echo "Mood: " + x[3]
            echo "----"
    of "shell":
        echo "Journal - Shell mode"
        echo "Write text here to write in to the journal, bypassing any restrictions that may come from writing in to the command arguments."
        var input = readLineFromStdin("> ").split(" ")
        input.writeToJournal
    of "v", "version":
        echo NJVERSION
    else:
        echo "Invalid command."
db = open(getHomeDir()&"/njournal.db", "", "", "")
main()
