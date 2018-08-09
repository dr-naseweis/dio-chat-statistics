# NAME

stat\_dio\_chat - collects statistics from dio chat protocol for browser game Grepolis

# SYNOPSIS

```perl
stat_dio_chat.pl [options]

Options:

 -m     script mode, one-of (download|index|process)
 -o     option parameter for mode
 -p     process mode, one-of (stats|multi|ip|addresses|start)
 -n     restrict output
 -i     ip adddress
 -s     start index
 -h     this helpfile

Examples:
  
  See the following example on working with world C<de92>. We start with downloading the complete chat log to C<de92.json> and afterwards extract some information.

     stat_dio_chat.pl -m download -o de92
         
  Lets see some statistics, optionallay limiting output to three entries
      
     stat_dio_chat.pl -m process -o de92.json -p stats -n 3

  Find out all ip-addresses that are used by more than one player
      
     stat_dio_chat.pl -m process -o de92.json -p multi
         
  List all messages attached to a certain ip-address
      
     stat_dio_chat.pl -m process -o de92.json -p ip -i <ip-address>
              
  Finally list ten messages after given index
      
    stat_dio_chat.pl .m process -o de92.json -p start -s 1000 -n 10
 
```

# DESCRIPTION

The browser script `DIO-Tools` is an add-on for the game `Grepolis`, that contains a chat function. This chat function is uploading player messages to a centralized web based location that can easily addressed by noisy people. This scripts provides easy access to stored chat logs. For performance sake it also contains persisting current world chats on users local file storage so online parsing is prohibited.

# OPTIONS

- **-m modus**
    - `download`

        Downloads live chat, additionally needs world as parameter, see `-o`
        Writes output as json to generated filename from worldcode, e.g. _de92.json_

    - `index`

        Returns last chat message id to console, additionally needs world as parameter, see `-o`

    - `process`

        processes already downloaded file, additionally needs input file (see `-o`) and process mode (see `-p`)
- **-o option parameter**, depending on used _mode_
    - `download`

        In download mode referes to internal world code to download, e.g. `de92`

    - `index`

        In index mode referes to internal world code to download, e.g. `de92`

    - `process`

        In process mode referes to filemame to load from, e.g. `de92.json`
- **-p process**

    One of `addresses`, `ip`, `multi`, `stats` or `start`

    - `addresses`

        Lists ip addresses of players.

    - `ip`

        Lists all messages using given ip-address, additionally needs parameter _-i ip_

    - `multi`

        Lists ip-addresses that are used by different player names and amount of their posts.

    - `stats`

        Shows current player posting stats, ordered by amount of posts. Can be restricted by _-n number_.
        Additionally lists amount of different ip-addresses a player is using as well as a messages-per-ip ratio.

    - `start`

        Show amount of messages after start index, additionally set by i<-s number>. Can be restricted by _-n number_.

- `-i ip-address`

    IP-Address to list messages for. Only to be used in processing mode `ip`.

- `-s number`

    Starting index when displaying n-th chat message in timelime. Only to be used in processing mode `start`.

- `-n number`

    Restrict output to ámount of `n` entries. Can be used in conjunction with processing modes `stats`, `start` and `multi`.

# COPYRIGHT

Copyright 2018 Dr. Naseweis <dr.naseweis@protomail.com>

# AUTHOR

Dr. Naseweis <dr.naseweis@protonmail.com>
