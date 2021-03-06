#!/bin/bash

## Set up the running environment
# Making sure spaces are not interpreted as newline
SAVEIFS=$IFS
IFS=$(echo -e "\n\b")
# Making sure PATH variable contains all necessary binary paths
path_backup="$PATH";
initial_path=":$PATH:";
new_path="$PATH";
for test_path in $(echo -e "/usr/local/sbin\n/usr/local/bin\n/usr/sbin\n/usr/bin\n/sbin\n/bin\n/usr/games\n/usr/bin\n/bin\n/usr/sbin\n/sbin\n/usr/local/bin\n/usr/X11/bin\n/Applications\n/opt/syb/sigma/bdj/jvm/bin\n/usr/bin/X11\n/opt/syb/app/bin\n/opt/syb/app/sbin\n/opt/syb/sigma/bin\n/nmt/apps"); do
	if [[ -d "$test_path" && "$initial_path" != *:$test_path:* ]]; then
		new_path="$new_path:$test_path";
	fi
done
export PATH="$new_path"

for bin in $(echo -e "basename\ncat\nchmod\nchown\ndate\ndirname\ndu\necho\negrep\nexpr\nfind\ngrep\nid\nls\nmkdir\nmv\nrm\nsed\ntouch\nwc"); do
	if [ ! -x "$(which "$bin")" ]; then missing_bin="$missing_bin\n$bin"; fi
done
if [ "$missing_bin" ]; then
	if [ -t 1 ]; then echo -e "Sorry but this script cannot be run. Those binaries are missing :\n$missing_bin\n\n"; fi;
	exit;
fi


##################################################################################
##                   TORRENTEXPANDER 
##                   v0.21
##
## You can use and modify this script to your convenience
## Any suggestion on how to improve this script will be welcome
##
##
## There are various ways to run this script as a daemon :
## - It can be invoked with the command torrentexpander.sh "/Path/to/your/torrent"
## - It can be triggered by the Transmission torrent client
## - You can export torrent="/Path/to/your/torrent" and start torrentexpander.sh
## - If you want Flexget to trigger torrentexpander.sh, have it echo the torrent path
##   to a file and start torrentexpander.sh. The third_party_log file will be used 
##   as a source file for torrentexpander.sh and the resulting files will then be
##   listed in this third_party_log file.
## - You can edit your settings in the torrentexpander_settings.ini file that will
##   be created the first time this script is launched. You can also access your 
##   settings by starting this script with the command /path/to/torrentexpander.sh -c
##
## If youre running this script manually you ll get a basic GUI that will enable you to
## choose a torrent file or folder and the destination where it should be expanded
## 
##################################################################################

##################################################################################
############################# REQUIRED SOFTWARE ##################################
# unrar
# unrar-nonfree
# unzip
################## SOFTWARE USED BY OPTIONAL FUNCTIONALITIES #####################
## Convert DTS track from MKV files to AC3
# https://github.com/JakeWharton/mkvdts2ac3/blob/master/mkvdts2ac3.sh
# http://www.bunkus.org/videotools/mkvtoolnix/downloads.html
# http://www.videolan.org/developers/libdca.html
# http://aften.sourceforge.net/
## Convert IMG to ISO 
# http://sourceforge.net/projects/ccd2iso/
##################################################################################
############################### END SOFTWARE #####################################

##################################################################################
################################ USER VARIABLES ##################################
########################### These variables are required #########################
################# On 1st run they will be stored in an ini file###################
## The destination folder is where files will be extracted
## I recommend using a different folder from the one where your torrents are located
## A sub directory of your torrents directory is fine though.
## If you really want to extract your torrents in-place and delete the
## original torrent, switch destructive_mode to yes
destination_folder="/path/to/your/destination/folder/"
destructive_mode="no"
################################ Software paths ##################################
################# Please check if these variables are correct ####################
unrar_bin="/usr/local/bin/unrar"
unzip_bin="/usr/local/bin/unzip"
wget_curl="/usr/local/bin/wget"
ccd2iso_bin="/usr/bin/ccd2iso"
mkvdts2ac3_bin="/path/to/mkvdts2ac3.sh"
##################### Supported file extensions - Comma separated ################
########### You must have at least one extension enabled in each field ###########
############### DON T ADD RAR OR ZIP EXTENSIONS IN THESE FIELDS ##################
supported_extensions="avi,mkv,divx,mp4,ts,iso,img,mp3,m4a,wav,srt,idx,sub,dvd"
tv_show_extensions="avi,mkv,divx,mp4,srt,idx,sub"
movies_extensions="avi,mkv,divx,mp4,ts,iso,img,srt,idx,sub"
music_extensions="mp3,m4a,wav"
##################### Movies detection patterns - Comma separated ################
############# You must have at least one pattern enabled in each field ###########
# movies_detect_patterns and movies_detect_patterns_pt_2 are the same - only splitted
# scene patterns is used for scenes that add their name at the beginning of the file name
movies_detect_patterns="HDTV,DVDRip,BDRip,BRRip,DVDR,576p,3D HSBS 720p,720p,3D HSBS 1080p,1080p,HD1080p"
movies_detect_patterns_pt_2="TS,PPVrip,TVRip,DVDSCR,R5,Workprint,SCR,Screener,HDRip,DVDScreener"
other_movies_patterns="pdtv,hdtv,xvid,webrip,web-dl,readnfo,ntsc,pal,ws,uncut,unrated,internal,480p,festival,bluray,extended,italian,dubbed,collection,season,nlsubs,spanish,divx,x264,hdtvrip,xxx,custom[. _-].*[. _-]subs,[^ ].*[. _-]subs,plsub,subtit,tsxvid,plsubbed,subbed,multisubs,multi-subs,fansub,retail,telesync,telecine,dvb,swesub,vostfr,3d,sbs,dvd,eng,dvd5,dvd9,torrent,torrents,www,x264,dvdripspanish,half-sbs,full-sbs"
scene_patterns="\[[. _-]*www[. _-].*[. _-].*[. _-]*\],aaf,dvdriptorrents,skidrow,klaxxon,axxo,vomit,dita,omifast,extratorrent,2lions,fxm,duqa,newartriot,nhanc3,ddc,keltz,\[fileking[. _-]pl\],fqm,eztv,limited,real[. _-]proper,proper,repack,resync,syncfix,rerip,theatrical.cut,remastered,convert,republic"
audio_quality_patterns="AC3,DTS,LiNE,CAM AUDIO,LD,Studio Audio"
####################### Optional functionalities variables #######################
#################### Set these variables to "no" to disable ######################
## Fix numbering for TV Shows - Switch variable to "yes" to enable
tv_shows_fix_numbering="yes"
## Cleanup Filenames - Switch variable to "yes" to enable
## 3 different schemas - type_1 = Movie (year).ext - type_2 = Movie Year (video_quality).ext - type_3 = Movie Year (audio_quality-video_quality).ext
clean_up_filenames="yes"
movies_rename_schema="type_1"
## Keep a dummy video file with the original filename for subtitles retrieval
## A torrentexpander_subtitles_dir directory will be created in the same directory as the script
## Fetch subtitles for files in this directory and on next run, torrentexpander will try to move them
## In the same directory as your movies
subtitles_handling="no"
## Repack handling - Switch variable to "yes" to enable
## Only useful if you want to be able to recognize repacks
repack_handling="no"
## Create Wii Cuesheet - Switch variable to "yes" to enable
## Will generate a CloneCD cuesheet for Wii backups
wii_post="no"
## Convert img to iso - Switch variable to "yes" to enable
## Will use CCD2ISO to convert .img disk images to .iso
img_post="no"
## Copy or move TV Shows to a specific folder - choose action (copy / move)
## and add path to enable.
## Using tv_shows_post_path_mode, series files can also be sorted by /Series/Episode (s)
## or /Series/Season X/Episode (ss) or /Series/Season XX/Episode (sss)
tv_shows_post="no"
tv_shows_post_path="no"
tv_shows_post_path_mode="no"
## Copy or move movies to a specific folder - choose action (copy / move)
## and add path to enable.
## You can also force folder creation for single file movies by setting force_single_file_movies_folder to yes
movies_post="no"
movies_post_path="no"
force_single_file_movies_folder="no"
## Copy or move music to a specific folder - choose action (copy / move)
## and add path to enable
music_post="no"
music_post_path="no"
## IMDB Integration - Mainly for NetworkedMediaTank
## Torrentexpander can generate a .nfo with imdb URL, dowonload a poster and download a fanart
## Id like to thank Loginbug for suggesting these imdb features and providing huge chunks of code
imdb_poster="no"
# Poster format could be: normal, large, small or full
imdb_poster_format="normal"
imdb_nfo="no"
imdb_fanart="no"
# Fanart format could be: thumb, poster, w1280, original
imdb_fanart_format="w1280"
# Disable NMJ scan it IMDB lookup fails
disable_nmj_scan="no"
## Convert DTS track from MKV files to AC3 - Check mkvdts2ac3.sh path and switch variable to "yes" to enable
## The DTS track will be kept and the AC3 track will be added
dts_post="no"
## Edit files and folders permissions - If you dont know what that means set it all to "no"
## If you don t want or can t use sudo, these features will be deprecated
user_perm_post="no"
group_perm_post="no"
files_perm_post="no"
folder_perm_post="no"
edit_perm_as_sudo="no"
## Use a source / resulting files log shared with a third party app - Add path to enable
## Take a look at the wiki to learn more about it
third_party_log="no"
## Reset timestamp (mtime)
reset_timestamp="no"
## Debug mode (only used in a few routines) - If enabled, it will be named torrentexpander_debug.log
## and stored in the same directory as the script
debug_mode="no"
## Auto Update script with latest svn release
## values can be "no", "daily" or "weekly"
auto_update_script="no"
## In destructive_mode, torrentexpander can pause then remove torrent and data from your transmission torrent client
remove_torrent_from_client="no"
torrent_daemon_bin="/usr/local/bin/transmission-remote"
torrent_daemon_login=""
torrent_daemon_password=""
torrent_daemon_port="9091"
## Run Script - Will be run once torrentexpander is done
## You can input the path to a script of your choice or just type the name of a binary available in your PATH
## 3 types of script can be run by torrentexpander :
## - all_files_script sends every processed file to the script
##      -> set any variable to file_path to send path to your script as $1, $2, $3, $4 or $5
##      -> set any variable to name_without_extension to send filename without extension to your script as $1, $2, $3, $4 or $5
##      -> set any variable to name_with_extension to send filename with extension to your script as $1, $2, $3, $4 or $5
##      -> set any variable to imdb_title to send IMDB title to your script as $1, $2, $3, $4 or $5
##      -> set any variable to imdb_id to send IMDB ID to your script as $1, $2, $3, $4 or $5
##      -> set any variable to imdb_url to send IMDB URL to your script as $1, $2, $3, $4 or $5
##      -> set any variable to imdb_poster_url to send IMDB Poster URL to your script as $1, $2, $3, $4 or $5
##      -> set any variable to tmdb_fanart_url to send TMDB Fanart URL to your script as $1, $2, $3, $4 or $5
## - processed_torrent_script sends only the resulting file or directory to the script
##		-> post tasks will then switch from copy to move mode
##      -> set any variable to file_path to send path to your script as $1, $2, $3, $4 or $5
##      -> set any variable to name_without_extension to send filename without extension to your script as $1, $2, $3, $4 or $5
##      -> set any variable to name_with_extension to send filename with extension to your script as $1, $2, $3, $4 or $5
##      -> set any variable to imdb_title to send IMDB title to your script as $1, $2, $3, $4 or $5
##      -> set any variable to imdb_id to send IMDB ID to your script as $1, $2, $3, $4 or $5
##      -> set any variable to imdb_url to send IMDB URL to your script as $1, $2, $3, $4 or $5
##      -> set any variable to imdb_poster_url to send IMDB Poster URL to your script as $1, $2, $3, $4 or $5
##      -> set any variable to tmdb_fanart_url to send TMDB Fanart URL to your script as $1, $2, $3, $4 or $5
## - post_run_script only triggers a script without sending any variable
###
all_files_script_enabled="no"
all_files_script=""
all_files_script_variable_1=""
all_files_script_variable_2=""
all_files_script_variable_3=""
all_files_script_variable_4=""
all_files_script_variable_5=""
###
processed_torrent_script_enabled="no"
processed_torrent_script=""
processed_torrent_script_variable_1=""
processed_torrent_script_variable_2=""
processed_torrent_script_variable_3=""
processed_torrent_script_variable_4=""
processed_torrent_script_variable_5=""
###
post_run_script_enabled="no"
post_run_script=""
###
############################ END USER VARIABLES ##################################
##################################################################################




##################################################################################
## Interpreting commandline options
commandline_arguments="$(echo -e "$*" | sed 's; -\([0-9a-zA-Z-]\);\\\n-\1;g' | sed 's; /\([0-9a-zA-Z-]\);\\\n/\1;g' )"
for arg in $(echo -e "$commandline_arguments"); do
	# Making sure the torrent fed into torrentexpander is a file or directory
	if [[ -f "$arg" || -d "$arg" ]] && [[ ! -f "$torrent" && ! -d "$torrent" ]]; then torrent=`echo "$arg"` && commandline_arguments="$(echo "$commandline_arguments" | egrep -v "^$arg$")";
	# alt_destination will be used instead of destination_folder if you launch the script using "/path/to/torrentexpander.sh /torrent /destination"
	elif [[ -d "$arg" ]] && [[ -f "$torrent" || -d "$torrent" ]]; then alt_dest_enabled="yes" && alt_destination=`echo "$arg"` && commandline_arguments="$(echo "$commandline_arguments" | egrep -v "^$arg$")";
	fi
done
for arg in $(echo -e "$commandline_arguments"); do
	# if the script is run for the first time or using "torrentexpander -c", launch setup
	if [[ "$arg" == "-c" || "$arg" == "--config" ]]; then first_run="yes";
	# Commandline arguments help
	elif [[ "$arg" == "-h" || "$arg" == "--help" ]] && [ -t 1 ]; then echo -e "\n\nAllowed commands are :\n\n-c  or --config            ->   Launch Setup\n-h  or --help              ->   Help\n-d  or --destructive       ->   Destructive Mode\n-nd or --non-destructive   ->   Disable Destructive Mode\n-s  or --silent            ->   Silent Mode (default if no display is available)\n-u  or --update            ->   Manual Update Mode\n\nFirst Path is your Torrent Path\nSecond Path is an Optional Destination Path of your choice\n\n" && exit;
	# Force destructive or non-destructive mode
	elif [[ "$arg" == "-d" || "$arg" == "--destructive" ]]; then force_destructive="yes";
	elif [[ "$arg" == "-nd" || "$arg" == "--non-destructive" ]]; then force_destructive="no";
	# if a torrent path is passed in commandline, we allow silent mode
	elif [[ "$arg" == "-s" || "$arg" == "--silent" ]] && [[ -f "$torrent" || -d "$torrent" ]]; then silent_mode="yes";
	# Manually trigger script update
	elif [[ "$arg" == "-u" || "$arg" == "--update" ]]; then update_mode="yes" && silent_mode="yes";
	fi
done

##################################################################################
## Gathering more info about the environment
# This routine is used to detect if the script can display output
# while in subtitles_mode, we never enable display
if [ -t 1 ] && [ "$subtitles_mode" != "yes" ] && [ "$silent_mode" != "yes" ]; then has_display="yes"; fi
# we ll remind the user about the help command
if [[ ! "$*" &&  "$has_display" == "yes" ]]; then echo -e "\n\nUse the -h or --help command if you need to see a list of all available commands\n\n"; fi

# Detect if the OS handles the nice command
nice -n 15 echo > /dev/null 2>&1 && if [ "$?" == "0" ]; then nice_available="yes"; fi

##################################################################################
## Save variables to another file. Updating the script will be less painful

# Detecting script path
PRG="$0"
while [ -h "$PRG" ] ; do
	ls=`ls -ld "$PRG"`
	link=`expr "$ls" : '.*-> \(.*\)$'`
	if expr "$link" : '/.*' > /dev/null; then
		PRG="$link"
	else
		PRG="`dirname -- "$PRG"`/$link"
	fi
done
script_path=`dirname -- "$PRG"`

# settings_file and debug_log will be stored in the same directory as the script
settings_file="$script_path/torrentexpander_settings.ini"
debug_log="$script_path/torrentexpander_debug.log"

# Defining path to subtitles directory. If run from Mac OS X Services, this feature will be disabled
subtitles_directory="$script_path/torrentexpander_subtitles_dir"
if [[ "$script_path" == *torrentexpander.workflow* ]]; then subtitles_handling="no"; fi

##################################################################################
######################### Script setup user interface ############################

# Switch to setup mode if settings file is missing and used interaction is possible
if [ -t 1 ] && [ ! -f "$settings_file" ]; then first_run="yes" && has_display="yes"; fi

# Generating settings file 
if [ ! -f "$settings_file" ]; then
	touch "$settings_file"
fi

# Detecting if gnu sed is available. Else switch to BSD sed routines
# sed -i will then be replaced by sed -i '' 
sed -i "s;^this_string_should_not_be_there$;^$;g" "$settings_file" > /dev/null 2>&1; if [ "$?" == "0" ]; then gnu_sed_available="yes"; fi

# Copying content of settings to a variable
check_settings=$(echo "$(cat "$settings_file")")


## Trying to guess default paths
# If destination_folder is not defined or unavailable, switch to Desktop on Mac and Ubuntu
# On NetworkedMediaTank, the script will use /share/Downloads/Expanded or /share/Download/Expanded
if [[ "$check_settings" != *estination_folder=* || "$check_settings" == *estination_folder=incorrect_or_not_se* ]]; then
	# This line should work on most unix systems
	if [ ! -d "$destination_folder" ] && [ -d "$HOME/Desktop" ]; then destination_folder="$HOME/Desktop"; fi
	# This line is for ubuntu systems when the desktop has a language specific name
	if [ ! -d "$destination_folder" ]; then xdg-user-dir > /dev/null 2>&1 && if [ "$?" == "0" ]; then destination_folder="$(xdg-user-dir DESKTOP)"; fi; fi
	# This line is for PopCornHour media players
	if [ ! -d "$destination_folder" ] && [ -d "/share/Downloads" ]; then destination_folder="/share/Downloads/Expanded";
	elif [ ! -d "$destination_folder" ] && [ -d "/share/Download" ]; then destination_folder="/share/Download/Expanded";
	fi
fi

# Looking for unrar in the PATH variable or /Applications /nmt/apps /usr/local/bin directories
if [[ "$check_settings" != *nrar_bin=* || "$check_settings" == *nrar_bin=incorrect_or_not_se* ]]; then
	if [ ! -x "$unrar_bin" ] && [ -x "$(for d in $(echo -e "/Applications\n/usr/local/bin\n/nmt/apps\n/bin\n/usr/bin\n$(echo -e "$PATH" | sed "s;:;\\\n;g")"); do if [ -d "$d" ]; then find "$d" -maxdepth 2 -name unrar; fi; done | sed -n -e '1p')" ]; then unrar_bin="$(for d in $(echo -e "/Applications\n/usr/local/bin\n/nmt/apps\n/bin\n/usr/bin\n$(echo -e "$PATH" | sed "s;:;\\\n;g")"); do if [ -d "$d" ]; then find "$d" -maxdepth 2 -name unrar; fi; done | sed -n -e '1p')"; fi
	# If unrar is unavailable, switch back to 7z
	if [ ! -x "$unrar_bin" ] && [ -x "$(for d in $(echo -e "/Applications\n/usr/local/bin\n/nmt/apps\n/bin\n/usr/bin\n$(echo -e "$PATH" | sed "s;:;\\\n;g")"); do if [ -d "$d" ]; then find "$d" -maxdepth 2 -name 7z; fi; done | sed -n -e '1p')" ]; then unrar_bin="$(for d in $(echo -e "/Applications\n/usr/local/bin\n/nmt/apps\n/bin\n/usr/bin\n$(echo -e "$PATH" | sed "s;:;\\\n;g")"); do if [ -d "$d" ]; then find "$d" -maxdepth 2 -name 7z; fi; done | sed -n -e '1p')"; fi
fi

# Looking for unzip in the PATH variable or /Applications /nmt/apps /usr/local/bin directories
if [[ "$check_settings" != *nzip_bin=* || "$check_settings" == *nzip_bin=incorrect_or_not_se* ]]; then
	if [ ! -x "$unzip_bin" ] && [ -x "$(for d in $(echo -e "/Applications\n/usr/local/bin\n/nmt/apps\n/bin\n/usr/bin\n$(echo -e "$PATH" | sed "s;:;\\\n;g")"); do if [ -d "$d" ]; then find "$d" -maxdepth 2 -name unzip; fi; done | sed -n -e '1p')" ]; then unzip_bin="$(for d in $(echo -e "/Applications\n/usr/local/bin\n/nmt/apps\n/bin\n/usr/bin\n$(echo -e "$PATH" | sed "s;:;\\\n;g")"); do if [ -d "$d" ]; then find "$d" -maxdepth 2 -name unzip; fi; done | sed -n -e '1p')"; fi
	# If unzip is unavailable, switch back to 7z
	if [ ! -x "$unzip_bin" ] && [ -x "$(for d in $(echo -e "/Applications\n/usr/local/bin\n/nmt/apps\n/bin\n/usr/bin\n$(echo -e "$PATH" | sed "s;:;\\\n;g")"); do if [ -d "$d" ]; then find "$d" -maxdepth 2 -name 7z; fi; done | sed -n -e '1p')" ]; then unzip_bin="$(for d in $(echo -e "/Applications\n/usr/local/bin\n/nmt/apps\n/bin\n/usr/bin\n$(echo -e "$PATH" | sed "s;:;\\\n;g")"); do if [ -d "$d" ]; then find "$d" -maxdepth 2 -name 7z; fi; done | sed -n -e '1p')"; fi
fi

# Looking for wget or curl in the PATH variable or /Applications /nmt/apps /usr/local/bin directories
if [[ "$check_settings" != *get_curl=* || "$check_settings" == *get_curl=incorrect_or_not_se* ]]; then
	# Looking for wget
	if [ ! -x "$wget_curl" ] && [ -x "$(for d in $(echo -e "/Applications\n/usr/local/bin\n/nmt/apps\n/bin\n/usr/bin\n$(echo -e "$PATH" | sed "s;:;\\\n;g")"); do if [ -d "$d" ]; then find "$d" -maxdepth 2 -name wget; fi; done | sed -n -e '1p')" ]; then wget_curl="$(for d in $(echo -e "/Applications\n/usr/local/bin\n/nmt/apps\n/bin\n/usr/bin\n$(echo -e "$PATH" | sed "s;:;\\\n;g")"); do if [ -d "$d" ]; then find "$d" -maxdepth 2 -name wget; fi; done | sed -n -e '1p')"; fi
	# If wget is unavailable, switch back to curl
	if [ ! -x "$wget_curl" ] && [ -x "$(for d in $(echo -e "/Applications\n/usr/local/bin\n/nmt/apps\n/bin\n/usr/bin\n$(echo -e "$PATH" | sed "s;:;\\\n;g")"); do if [ -d "$d" ]; then find "$d" -maxdepth 2 -name curl; fi; done | sed -n -e '1p')" ]; then wget_curl="$(for d in $(echo -e "/Applications\n/usr/local/bin\n/nmt/apps\n/bin\n/usr/bin\n$(echo -e "$PATH" | sed "s;:;\\\n;g")"); do if [ -d "$d" ]; then find "$d" -maxdepth 2 -name curl; fi; done | sed -n -e '1p')"; fi
fi

# Looking for ccd2iso in the PATH variable or /Applications /nmt/apps /usr/local/bin directories
if [[ "$check_settings" != *cd2iso_bin=* || "$check_settings" == *cd2iso_bin=incorrect_or_not_se* ]]; then
	if [ ! -x "$ccd2iso_bin" ] && [ -x "$(for d in $(echo -e "/Applications\n/usr/local/bin\n/nmt/apps\n/bin\n/usr/bin\n$(echo -e "$PATH" | sed "s;:;\\\n;g")"); do if [ -d "$d" ]; then find "$d" -maxdepth 2 -name ccd2iso; fi; done | sed -n -e '1p')" ]; then ccd2iso_bin="$(for d in $(echo -e "/Applications\n/usr/local/bin\n/nmt/apps\n/bin\n/usr/bin\n$(echo -e "$PATH" | sed "s;:;\\\n;g")"); do if [ -d "$d" ]; then find "$d" -maxdepth 2 -name ccd2iso; fi; done | sed -n -e '1p')"; fi
fi

# Looking for a text editor in the PATH variable or /Applications /nmt/apps /usr/local/bin directories
if [[ "$check_settings" != *ext_editor_bin=* || "$check_settings" == *ext_editor_bin=incorrect_or_not_se* ]]; then
	if [ ! -x "$text_editor_bin" ] && [ -x "$(for d in $(echo -e "/Applications\n/usr/local/bin\n/nmt/apps\n/bin\n/usr/bin\n$(echo -e "$PATH" | sed "s;:;\\\n;g")"); do if [ -d "$d" ]; then find "$d" -maxdepth 2 -name nano; fi; done | sed -n -e '1p')" ]; then text_editor_bin="$(for d in $(echo -e "/Applications\n/usr/local/bin\n/nmt/apps\n/bin\n/usr/bin\n$(echo -e "$PATH" | sed "s;:;\\\n;g")"); do if [ -d "$d" ]; then find "$d" -maxdepth 2 -name nano; fi; done | sed -n -e '1p')"; fi
	# If nano is unavailable, switch back to vi
	if [ ! -x "$text_editor_bin" ] && [ -x "$(for d in $(echo -e "/Applications\n/usr/local/bin\n/nmt/apps\n/bin\n/usr/bin\n$(echo -e "$PATH" | sed "s;:;\\\n;g")"); do if [ -d "$d" ]; then find "$d" -maxdepth 2 -name vi; fi; done | sed -n -e '1p')" ]; then text_editor_bin="$(for d in $(echo -e "/Applications\n/usr/local/bin\n/nmt/apps\n/bin\n/usr/bin\n$(echo -e "$PATH" | sed "s;:;\\\n;g")"); do if [ -d "$d" ]; then find "$d" -maxdepth 2 -name vi; fi; done | sed -n -e '1p')"; fi
fi

# Looking for a torrent client in the PATH variable or /Applications /nmt/apps /usr/local/bin directories
if [[ "$check_settings" != *orrent_daemon_bin=* || "$check_settings" == *orrent_daemon_bin=incorrect_or_not_se* ]]; then
	if [ ! -x "$torrent_daemon_bin" ] && [ -x "$(for d in $(echo -e "/share/Apps/Transmission/bin\n/Applications\n/usr/local/bin\n/nmt/apps\n/bin\n/usr/bin\n$(echo -e "$PATH" | sed "s;:;\\\n;g")"); do if [ -d "$d" ]; then find "$d" -maxdepth 2 -name transmission-remote; fi; done | sed -n -e '1p')" ]; then torrent_daemon_bin="$(for d in $(echo -e "/share/Apps/Transmission/bin\n/Applications\n/usr/local/bin\n/nmt/apps\n/bin\n/usr/bin\n$(echo -e "$PATH" | sed "s;:;\\\n;g")"); do if [ -d "$d" ]; then find "$d" -maxdepth 2 -name transmission-remote; fi; done | sed -n -e '1p')"; fi
	# If transmission-remote is unavailable we give xmlrpc a try
	if [ ! -x "$torrent_daemon_bin" ] && [ -x "$(for d in $(echo -e "/Applications\n/usr/local/bin\n/nmt/apps\n/bin\n/usr/bin\n$(echo -e "$PATH" | sed "s;:;\\\n;g")"); do if [ -d "$d" ]; then find "$d" -maxdepth 2 -name xmlrpc; fi; done | sed -n -e '1p')" ]; then torrent_daemon_bin="$(for d in $(echo -e "/Applications\n/usr/local/bin\n/nmt/apps\n/bin\n/usr/bin\n$(echo -e "$PATH" | sed "s;:;\\\n;g")"); do if [ -d "$d" ]; then find "$d" -maxdepth 2 -name xmlrpc; fi; done | sed -n -e '1p')"; fi
fi

# Looking for all_files_script in your PATH variable or /Applications /nmt/apps /usr/local/bin directories
if [ "$all_files_script" ] && [[ "$check_settings" != *ll_files_script=* || "$check_settings" == *ll_files_script=incorrect_or_not_se* ]]; then
	if [ ! -x "$all_files_script" ] && [ -x "$(for d in $(echo -e "/Applications\n/usr/local/bin\n/nmt/apps\n/bin\n/usr/bin\n/share/Apps/TorrentExpander/bin/\n$(echo -e "$PATH" | sed "s;:;\\\n;g")"); do if [ -d "$d" ]; then find "$d" -maxdepth 2 -name "$all_files_script"; fi; done | sed -n -e '1p')" ]; then all_files_script="$(for d in $(echo -e "/Applications\n/usr/local/bin\n/nmt/apps\n/bin\n/usr/bin\n/share/Apps/TorrentExpander/bin/\n$(echo -e "$PATH" | sed "s;:;\\\n;g")"); do if [ -d "$d" ]; then find "$d" -maxdepth 2 -name "$all_files_script"; fi; done | sed -n -e '1p')"; fi
fi

# Looking for processed_torrent_script in your PATH variable or /Applications /nmt/apps /usr/local/bin directories
if [ "$processed_torrent_script" ] && [[ "$check_settings" != *rocessed_torrent_script=* || "$check_settings" == *rocessed_torrent_script=incorrect_or_not_se* ]]; then
	if [ ! -x "$processed_torrent_script" ] && [ -x "$(for d in $(echo -e "/Applications\n/usr/local/bin\n/nmt/apps\n/bin\n/usr/bin\n/share/Apps/TorrentExpander/bin/\n$(echo -e "$PATH" | sed "s;:;\\\n;g")"); do if [ -d "$d" ]; then find "$d" -maxdepth 2 -name "$processed_torrent_script"; fi; done | sed -n -e '1p')" ]; then processed_torrent_script="$(for d in $(echo -e "/Applications\n/usr/local/bin\n/nmt/apps\n/bin\n/usr/bin\n/share/Apps/TorrentExpander/bin/\n$(echo -e "$PATH" | sed "s;:;\\\n;g")"); do if [ -d "$d" ]; then find "$d" -maxdepth 2 -name "$processed_torrent_script"; fi; done | sed -n -e '1p')"; fi
fi

# Looking for post_run_script in your PATH variable or /Applications /nmt/apps /usr/local/bin directories
if [ "$post_run_script" ] && [[ "$check_settings" != *ost_run_script=* || "$check_settings" == *ost_run_script=incorrect_or_not_se* ]]; then
	if [ ! -x "$post_run_script" ] && [ -x "$(for d in $(echo -e "/Applications\n/usr/local/bin\n/nmt/apps\n/bin\n/usr/bin\n/share/Apps/TorrentExpander/bin/\n$(echo -e "$PATH" | sed "s;:;\\\n;g")"); do if [ -d "$d" ]; then find "$d" -maxdepth 2 -name "$post_run_script"; fi; done | sed -n -e '1p')" ]; then post_run_script="$(for d in $(echo -e "/Applications\n/usr/local/bin\n/nmt/apps\n/bin\n/usr/bin\n/share/Apps/TorrentExpander/bin/\n$(echo -e "$PATH" | sed "s;:;\\\n;g")"); do if [ -d "$d" ]; then find "$d" -maxdepth 2 -name "$post_run_script"; fi; done | sed -n -e '1p')"; fi
fi

# Inserting path to binaries into the settings file
for c in $(echo -e "unrar_bin\nunzip_bin\nwget_curl\nccd2iso_bin\ntext_editor_bin\nmkvdts2ac3_bin\ntorrent_daemon_bin\nall_files_script\nprocessed_torrent_script\npost_run_script"); do
	pat="$(echo "$c" | sed "s;^.\(.*\)$;\*\1=\*;")"
	pat_two="$(echo "$c" | sed "s;^.\(.*\)$;\*\1=incorrect_or_not_se\*;")"
	if [[ "$check_settings" != $pat && -x "${!c}" ]] || [[ "$check_settings" == $pat_two && -x "${!c}" ]]; then
		if [[ "$check_settings" == $pat_two && "$gnu_sed_available" != "yes" ]]; then sed -i '' "/$c=/d" "$settings_file"; fi;
		if [[ "$check_settings" == $pat_two && "$gnu_sed_available" == "yes" ]]; then sed -i "/$c=/d" "$settings_file"; fi;
		echo "$c=${!c}" >> "$settings_file"
	elif [[ "$check_settings" != $pat ]]; then echo "$c=incorrect_or_not_set" >> "$settings_file"
	fi
done

# Inserting destinations paths into settings file
for c in $(echo -e "destination_folder\ntv_shows_post_path\nmovies_post_path\nmusic_post_path"); do
	pat="$(echo "$c" | sed "s;^.\(.*\)$;\*\1=\*;")"
	pat_two="$(echo "$c" | sed "s;^.\(.*\)$;\*\1=n\*;")"
	if [[ "$check_settings" != $pat && -d "${!c}" ]] || [[ "$check_settings" == $pat_two && -d "${!c}" ]]; then
		if [[ "$check_settings" == $pat_two && "$gnu_sed_available" != "yes" ]]; then sed -i '' "/$c=/d" "$settings_file"; fi;
		if [[ "$check_settings" == $pat_two && "$gnu_sed_available" == "yes" ]]; then sed -i "/$c=/d" "$settings_file"; fi;
		echo "$c=${!c}" >> "$settings_file"
	elif [[ "$check_settings" != $pat ]]; then echo "$c=no" >> "$settings_file"
	fi
done

# Adding path to third party log into settings file
if [ "$third_party_log" != "no" ]; then third_party_log_directory="$(echo "$(dirname "$third_party_log")")"; fi
if [[ "$check_settings" != *hird_party_log=* && -d "$third_party_log_directory" ]] || [[ "$check_settings" == *hird_party_log=n* && -d "$third_party_log_directory" ]]; then
	if [[ "$check_settings" == *hird_party_log=n* && "$gnu_sed_available" != "yes" ]]; then sed -i '' "/third_party_log=/d" "$settings_file"; fi;
	if [[ "$check_settings" == *hird_party_log=n* && "$gnu_sed_available" == "yes" ]]; then sed -i "/third_party_log=/d" "$settings_file"; fi;
	echo "third_party_log="$third_party_log"" >> "$settings_file";
elif [[ "$check_settings" != *hird_party_log=* ]]; then echo "third_party_log=no" >> "$settings_file"
fi

# Adding other values in settings file
for c in $(echo -e "destructive_mode\nuser_defined_other_movies_patterns\nuser_defined_scene_patterns\nuser_defined_scene_patterns_hothead_edition\ntv_shows_fix_numbering\nclean_up_filenames\nmovies_rename_schema\nsubtitles_handling\nrepack_handling\nwii_post\nimg_post\ntv_shows_post\ntv_shows_post_path_mode\nmovies_post\nforce_single_file_movies_folder\nmusic_post\nimdb_poster\nimdb_poster_format\nimdb_nfo\nimdb_fanart\nimdb_fanart_format\ndisable_nmj_scan\ndts_post\nuser_perm_post\ngroup_perm_post\nfiles_perm_post\nfolder_perm_post\nedit_perm_as_sudo\nreset_timestamp\nsupported_extensions\ntv_show_extensions\nmovies_extensions\nmusic_extensions\ndebug_mode\nauto_update_script\nremove_torrent_from_client\ntorrent_daemon_login\ntorrent_daemon_password\ntorrent_daemon_port\nall_files_script_enabled\nall_files_script_variable_1\nall_files_script_variable_2\nall_files_script_variable_3\nall_files_script_variable_4\nall_files_script_variable_5\nprocessed_torrent_script_enabled\nprocessed_torrent_script_variable_1\nprocessed_torrent_script_variable_2\nprocessed_torrent_script_variable_3\nprocessed_torrent_script_variable_4\nprocessed_torrent_script_variable_5\npost_run_script_enabled"); do
	pat="$(echo "$c" | sed "s;^.\(.*\)$;\*\1=\*;")"
	if [[ "$check_settings" != $pat ]]; then echo "$c=${!c}" >> "$settings_file"; fi
done

# Removing patterns from settings file generated by a previous version of the script
if [[ "$check_settings" == *ovies_detect_patterns=* && "$gnu_sed_available" != "yes" ]]; then sed -i '' "/movies_detect_patterns=/d" "$settings_file"; fi
if [[ "$check_settings" == *ovies_detect_patterns=* && "$gnu_sed_available" == "yes" ]]; then sed -i "/movies_detect_patterns=/d" "$settings_file"; fi

# Add quotes in settings file
if [ "$(echo "$check_settings" | egrep -i "([\\]) ")" ] && [ "$gnu_sed_available" != "yes" ]; then sed -i '' 's;\\ ; ;g' "$settings_file"; fi
if [ "$(echo "$check_settings" | egrep -i "([\\]) ")" ] && [ "$gnu_sed_available" == "yes" ]; then sed -i 's;\\ ; ;g' "$settings_file"; fi
if [ "$(echo "$check_settings" | egrep -i "([^\"]) ")" ] && [ "$gnu_sed_available" != "yes" ]; then sed -i '' 's;^\(.*\)=\([^"]\)\(.*\)\([^"]\)$;\1="\2\3\4";g' "$settings_file"; fi
if [ "$(echo "$check_settings" | egrep -i "([^\"]) ")" ] && [ "$gnu_sed_available" == "yes" ]; then sed -i 's;^\(.*\)=\([^"]\)\(.*\)\([^"]\)$;\1="\2\3\4";g' "$settings_file"; fi

# Fetching values from settings file
source "$settings_file"

# Adding trailing slash to destination paths
if [[ "$tv_shows_post_path" != */ ]] && [ "$tv_shows_post" != "no" ]; then tv_shows_post_path="$tv_shows_post_path/"; fi
if [[ "$music_post_path" != */ ]] && [ "$music_post_path" != "no" ]; then music_post_path="$music_post_path/"; fi
if [[ "$movies_post_path" != */ ]] && [ "$movies_post_path" != "no" ]; then movies_post_path="$movies_post_path/"; fi

# Override destructive-mode setting using commandline argument
if [ "$force_destructive" == "yes" ]; then destructive_mode="yes"; elif [ "$force_destructive" == "no" ]; then destructive_mode="no"; fi

# Making patterns regexp friendly
supported_extensions_rev="\.$(echo $supported_extensions | sed 's;,;\$\|\\\.;g')$"
tv_show_extensions_rev="\.$(echo $tv_show_extensions | sed 's;,;\$\|\\\.;g')$"
movies_extensions_rev="\.$(echo $movies_extensions | sed 's;,;\$\|\\\.;g')$"
music_extensions_rev="\.$(echo $music_extensions | sed 's;,;\$\|\\\.;g')$"
movies_detect_patterns_rev="[^[:alnum:]]$(echo $movies_detect_patterns | sed 's;,;[^[:alnum:]]|[^[:alnum:]];g')[^[:alnum:]]"
movies_detect_patterns_pt_2_rev="[^[:alnum:]]$(echo $movies_detect_patterns_pt_2 | sed 's;,;[^[:alnum:]]|[^[:alnum:]];g')[^[:alnum:]]"
other_movies_patterns="$other_movies_patterns,$audio_quality_patterns,$user_defined_other_movies_patterns"
scene_patterns="$scene_patterns,$user_defined_scene_patterns"

##################################################################################
############################### Setup Assistant ##################################
if [ "$first_run" == "yes" ] && [ "$has_display" == "yes" ]; then echo -e "----------------------------------------------------\n----------------------------------------------------\n\nWELCOME TO TORRENTEXPANDER\n\n----------------------------------------------------\n----------------------------------------------------\n\n"; fi
if [ "$first_run" == "yes" ] && [ "$has_display" == "yes" ]; then echo -e "This is the first time you're running this script\nA few settings are required for it to run\nThese required settings are :\n- The destination_folder -> This is where the content of your torrents will be expanded / copied\n- unrar_bin -> This is the path to the Unrar binary. If it's not already installed on your computer then Google is your friend\n- unzip_bin -> This is the path to the Unrar binary. It's probably already installed on your computer\n\nAll other options are already set to their default value\nIf you want more details about those options, open this script with a text editor\n\nA nano or vi text editor will now open so that you can edit your settings\nTo save them in nano you'll have to press Control-X then Y then Enter\nTo save them in vi you'll have to press Escape then type :wq then press Enter\n\nOnce you're ready press Enter" && read -p ""; fi
if [ "$first_run" == "yes" ] && [ "$has_display" == "yes" ]; then "$text_editor_bin" "$settings_file" && echo -e "\n\nYou're done with your setup\nThis script will exit now\nIf you need to edit your settings again just run $script_path/torrentexpander.sh -c" && exit; fi

##################################################################################
###################### Kinda graphical user interface ############################
if [[ "$has_display" == "yes" && ! "$torrent" ]] || [[ "$has_display" == "yes" && ! "$alt_dest_enabled" ]]; then echo -e "\n\n----------------------------------------------------\n----------------------------------------------------\n\nWELCOME TO TORRENTEXPANDER\n\n----------------------------------------------------\n----------------------------------------------------\n\n"; fi

## Trying to find out transmission download-dir from transmission settings file - Temporarily disabled until I find a better one
transmission_settings_file="$(if [ -f "/share/Apps/Transmission/config/settings.json" ]; then echo "/share/Apps/Transmission/config/settings.json"; elif [ -f "/share/.transmission/settings.json" ]; then echo "/share/.transmission/settings.json"; elif [ -f "$HOME/.config/transmission/settings.json" ]; then echo "$HOME/.config/transmission/settings.json"; fi)"
if [ "$has_display" == "yes" ] && [ -f "$transmission_settings_file" ] && [ ! "$torrent" ]; then cd "$(echo "$(sed -n '/"download-dir": /p' "$transmission_settings_file")" | sed -e 's/    "download-dir": "//g' -e 's/", //g')"; elif [ "$has_display" == "yes" ] && [ ! -f "$transmission_settings_file" ] && [ ! "$torrent" ]; then cd "$HOME"; fi

## Asking the User for the torrent source
selected=0
item_selected=""
if [ "$has_display" == "yes" ] && [ ! "$torrent" ]; then
	while [[ $selected -eq 0 ]] ; do
		count=-1 && echo "Select Torrent Source :" && echo "" && echo "$(pwd)" && echo ""
		# Listing content of directory in the GUI
		for item in $(echo -e "Select current folder\n..\n$(ls -1)"); do
			count=$(( $count + 1 )); var_name="sel$count"; var_val="$item"; eval ${var_name}=`echo -e \""${var_val}"\"`; echo "$count - $item"
		done
		echo "" && echo "Type the ID of the Torrent Source :"
		# Asking user for its selection
		read answer && sel_item="$(echo "sel$answer")"
		item_selected=${!sel_item}
		# If selection is 0, current directory is selected as the source
		if [ "$item_selected" == "Select current folder" ]; then item_selected="$(pwd)" && selected=1
		# If selection is 1, switch to parent directory
		elif [ "$item_selected" == ".." ]; then cd "$(dirname $(pwd))"
		# Preventing an issue when climbing up to root directory
		elif [[ "$(pwd)" == "/" && -d "/$item_selected" ]]; then cd "/$item_selected"
		# cd to the selected directory
		elif [ -d "$(pwd)/$item_selected" ]; then cd "$(pwd)/$item_selected"
		# if item is a file, the item is then selected as the source
		elif [ -f "$(pwd)/$item_selected" ]; then item_selected="$(pwd)/$item_selected" && selected=1
		fi
		echo ""
	done
fi

# Display selected source
if [ "$has_display" == "yes" ] && [ ! "$torrent" ] && [ "$item_selected" ] && [[ $selected -eq 1 ]]; then torrent="$item_selected" && echo "" && echo "Your File Source is $torrent" && echo "" && echo ""; fi

## Asking the User for the torrent destination - A default destination can be set by inserting a gui_transmission_destination in the settings file
if [ "$has_display" == "yes" ] && [ ! "$alt_dest_enabled" ] && [ ! "$alt_destination" ] && [ "$gui_transmission_destination" ]; then cd "$gui_transmission_destination"; elif [[ "$has_display" == "yes" && ! "$alt_dest_enabled" && ! "$alt_destination" && -d "$destination_folder" ]]; then cd "$destination_folder"; elif [ "$has_display" == "yes" ] && [ ! "$alt_dest_enabled" ] && [ ! "$alt_destination" ]; then cd "$HOME"; fi
selected=0
item_selected=""
if [ "$has_display" == "yes" ] && [ ! "$alt_dest_enabled" ] && [ ! "$alt_destination" ]; then
	while [[ $selected -eq 0 ]] ; do
		count=-1 && echo "" && echo "Select Destination Folder :" && echo "" && echo "$(pwd)" && echo ""
		# Listing content of directory in the GUI
		for item in $(echo -e "Select current folder\n..\n$(ls -1)"); do
			count=$(( $count + 1 )); var_name="sel$count"; var_val="$item"; eval ${var_name}=`echo -e \""${var_val}"\"`; echo "$count  -  $item"
		done
		echo "" && echo "Type the ID of the Destination Folder :"
		# Asking user for its selection
		read answer && sel_item="$(echo "sel$answer")"
		item_selected=${!sel_item}
		# If selection is 0, current directory is selected as the destination
		if [ "$item_selected" == "Select current folder" ]; then item_selected="$(pwd)" && selected=1
		# If selection is 1, switch to parent directory
		elif [ "$item_selected" == ".." ]; then cd "$(dirname $(pwd))"
		# Preventing an issue when climbing up to root directory
		elif [[ "$(pwd)" == "/" && -d "/$item_selected" ]]; then cd "/$item_selected"
		# cd to the selected directory
		elif [ -d "$(pwd)/$item_selected" ]; then cd "$(pwd)/$item_selected"
		# if item is a file, the item is then selected as the destination
		elif [ -f "$(pwd)/$item_selected" ]; then cd "$(pwd)"
		fi
		echo ""
	done
fi

# Display selected destination
if [ "$has_display" == "yes" ] && [ ! "$alt_dest_enabled" ] && [ ! "$alt_destination" ] && [ "$item_selected" ] && [[ $selected -eq 1 ]]; then alt_dest_enabled="yes" && alt_destination="$item_selected" && echo "" && echo "Your Destination Folder is $alt_destination" && echo "" && echo ""; fi

if [ "$alt_dest_enabled" == "yes" ]; then destination_folder=`echo "$alt_destination"`; fi
if [[ "$destination_folder" != */ ]]; then destination_folder="$destination_folder/"; fi

## This temp folder is used for zip archives and dts conversion and will be
## automatically removed. By default it will be created in your destination folder
torrentexpander_temp="torrentexpander_temp"
temp_folder="$(echo "$destination_folder$torrentexpander_temp/")"
temp_folder_without_slash="$(echo "$destination_folder$torrentexpander_temp")"

##################################################################################
############################# TORRENT SOURCE SETUP ###############################
################# You probably dont need to do anything here #####################
## This script will use a variable named torrent if file, else cd variable torrent, 
## else use transmission variables if file, else cd transmission variables,
## else use current folder
if [ "$TR_TORRENT_NAME" ] && [ ! "$torrent" ]; then
	torrent="$TR_TORRENT_DIR/$TR_TORRENT_NAME";
	torrent_name="$TR_TORRENT_NAME";
fi
if [[ -f "$torrent" || -d "$torrent" ]] && [ -r "$torrent" ]; then
	delete_third_party_log="yes"
	if [ ! "$torrent_name" ] && [ "$torrent" ]; then torrent_name=`echo "$(basename "$torrent")"`; fi
	if [[ -d "$torrent" && -r "$torrent" ]]; then cd "$torrent" && current_folder=`echo "$(pwd)"` && folder_short=`echo "$( basename "$(pwd)" )"` && torrent=""; fi
elif [ "$third_party_log" != "no" ] && [[ -f "$third_party_log" && -w "$third_party_log" ]]; then
	torrent="$(cat "$third_party_log")"
	if [ ! "$torrent_name" ] && [ "$torrent" ]; then torrent_name=`echo "$(basename "$torrent")"`; fi
	if [[ -d "$torrent" && -r "$torrent" ]]; then cd "$torrent" && current_folder=`echo "$(pwd)"` && folder_short=`echo "$( basename "$(pwd)" )"` && torrent=""; fi
elif [ "$has_display" == "yes" ]; then
	echo "I cannot detect any Torrent Source or permissions to this torrent are not set correctly - This script will exit" && exit
elif [ "$update_mode" == "yes" ]; then echo > /dev/null 2>&1
else exit
fi

######################### END TORRENT SOURCE SETUP ###############################
##################################################################################

##################### CHECKING IF VARIABLES ARE CORRECT ##########################
variables_check="Please check your script variables"
temp_directory="$(echo "$(dirname "$temp_folder")")"
third_party_log_directory="$(echo "$(dirname "$third_party_log")")"
errors_file="$script_path/torrentexpander_errors.log"
if [ "$torrent" ] && [ ! "$current_folder" ]; then
	torrent_directory="$(echo "$(dirname "$torrent")/")"
elif [ "$current_folder" ] && [ ! "$torrent" ]; then
	torrent_directory="$(echo "$(dirname "$current_folder")/")"
fi

# Deleting previous error file
if [ -f "$errors_file" ]; then rm -f "$errors_file"; fi

# If variables are correct, notify the user directly or through an error file generated in the script directory
# If some necessary variables are incorrect, the script will exit
# If some optional variables are incorrect, the script will continue but those features will be disabled

if [ ! -d "$(dirname "$destination_folder")" ]; then echo "Your destination folder is incorrect please edit your torrentexpander_settings.ini file" >> "$errors_file"; if [ "$has_display" == "yes" ]; then echo -e "Your destination folder is incorrect please edit your torrentexpander_settings.ini file\n"; fi; quit_on_error="yes"; fi
if [[ -d "$(dirname "$destination_folder")" && ! -d "$destination_folder" && -w "$(dirname "$destination_folder")" ]]; then mkdir -p "$destination_folder"; fi
if [[ ! -w "$destination_folder" || ! -d "$destination_folder" ]]; then echo "Permissions on your destination folder are incorrect please edit your torrentexpander_settings.ini file or your permissions for this folder" >> "$errors_file"; if [ "$has_display" == "yes" ]; then echo -e "\nPermissions on your destination folder are incorrect please edit your torrentexpander_settings.ini file or your permissions for this folder\n"; fi; quit_on_error="yes"; fi

## This part of the script has been moved a bit later in the script
# if [ ! -d "$temp_directory" ]; then echo "Your temp folder path is incorrect please edit your torrentexpander_settings.ini file" >> "$errors_file"; if [ "$has_display" == "yes" ]; then echo -e "\nYour temp folder path is incorrect please edit your torrentexpander_settings.ini file\n"; fi; quit_on_error="yes"; fi
# if [ -d "$temp_folder" ]; then echo "Temp folder already exists. Please delete it or edit your torrentexpander_settings.ini file" >> "$errors_file"; if [ "$has_display" == "yes" ]; then echo -e "\nTemp folder already exists. Please delete it or edit your torrentexpander_settings.ini file\n"; fi; quit_on_error="yes"; fi
# if [[ ! -w "$temp_directory" ]]; then echo "Permissions on your temp folder are incorrect please edit your torrentexpander_settings.ini file or your permissions for this folder" >> "$errors_file"; if [ "$has_display" == "yes" ]; then echo -e "\nPermissions on your temp folder are incorrect please edit your torrentexpander_settings.ini file or your permissions for this folder\n"; fi; quit_on_error="yes"; fi

if [ ! -d "$tv_shows_post_path" ] && [ "$tv_shows_post" != "no" ]; then	echo "Your TV Shows path is incorrect - TV Shows Post will be disabled" >> "$errors_file"; if [ "$has_display" == "yes" ]; then echo "Your TV Shows path is incorrect - TV Shows Post will be disabled"; fi; tv_shows_post="no"; fi
if [[ ! -w "$tv_shows_post_path" && "$tv_shows_post" != "no" ]]; then echo "Permissions on your TV Shows folder are incorrect please edit your torrentexpander_settings.ini file or your permissions for this folder - TV Shows Post will be disabled" >> "$errors_file"; if [ "$has_display" == "yes" ]; then echo -e "\nPermissions on your TV Shows folder are incorrect please edit your torrentexpander_settings.ini file or your permissions for this folder - TV Shows Post will be disabled\n"; fi; tv_shows_post="no"; fi
if [[ "$tv_shows_post_path_mode" != "s" && "$tv_shows_post_path_mode" != "ss" && "$tv_shows_post_path_mode" != "sss" && "$tv_shows_post_path_mode" != "no" ]]; then echo "Your TV Shows path mode is incorrect - TV Shows Post will be disabled" >> "$errors_file"; if [ "$has_display" == "yes" ]; then echo "Your TV Shows path mode is incorrect - TV Shows Post will be disabled"; fi; tv_shows_post="no"; fi

if [ ! -d "$music_post_path" ] && [ "$music_post" != "no" ]; then echo "Your music path is incorrect - Music Post will be disabled" >> "$errors_file"; if [ "$has_display" == "yes" ]; then echo "Your music path is incorrect - Music Post will be disabled"; fi; music_post="no"; fi
if [[ ! -w "$music_post_path" && "$music_post" != "no" ]]; then echo "Permissions on your Music folder are incorrect please edit your torrentexpander_settings.ini file or your permissions for this folder - Music Post will be disabled" >> "$errors_file"; if [ "$has_display" == "yes" ]; then echo -e "\nPermissions on your Music folder are incorrect please edit your torrentexpander_settings.ini file or your permissions for this folder - Music Post will be disabled\n"; fi; music_post="no"; fi

if [ ! -d "$movies_post_path" ] && [ "$movies_post" != "no" ]; then	echo "Your movies path is incorrect - Movies Post will be disabled" >> "$errors_file"; if [ "$has_display" == "yes" ]; then echo "Your movies path is incorrect - Movies Post will be disabled"; fi; movies_post="no"; fi
if [[ ! -w "$movies_post_path" && "$movies_post" != "no" ]]; then echo "Permissions on your Movies folder are incorrect please edit your torrentexpander_settings.ini file or your permissions for this folder - Movies Post will be disabled" >> "$errors_file"; if [ "$has_display" == "yes" ]; then echo -e "\nPermissions on your Movies folder are incorrect please edit your torrentexpander_settings.ini file or your permissions for this folder - Movies Post will be disabled\n"; fi; movies_post="no"; fi

if [ ! -d "$third_party_log_directory" ] && [ "$third_party_log" != "no" ]; then echo "Your third party log path is incorrect please edit your torrentexpander_settings.ini file" >> "$errors_file"; if [ "$has_display" == "yes" ]; then echo "Your third party log path is incorrect please edit your torrentexpander_settings.ini file"; fi; quit_on_error="yes"; fi
if [ ! -w "$third_party_log_directory" ] && [ "$third_party_log" != "no" ]; then echo "Your third party log path permissions are incorrect please edit your torrentexpander_settings.ini file or your permissions" >> "$errors_file"; if [ "$has_display" == "yes" ]; then echo -e "\nYour third party log path permissions are incorrect please edit your torrentexpander_settings.ini file or your permissions\n"; fi; quit_on_error="yes"; fi

if [ "$torrent_directory" == "$destination_folder" ] && [ "$destructive_mode" != "yes" ]; then echo "Your destination folder should be different from the one where your torrent is located. Please edit your torrentexpander_settings.ini file" >> "$errors_file"; if [ "$has_display" == "yes" ]; then echo -e "\nYour destination folder should be different from the one where your torrent is located. Please edit your torrentexpander_settings.ini file\n"; fi; quit_on_error="yes"; fi

if [ ! -x "$unrar_bin" ]; then echo "Your Unrar path is incorrect or permissions are incorrect please edit your torrentexpander_settings.ini file or edit your permissions" >> "$errors_file"; if [ "$has_display" == "yes" ]; then echo -e "\nYour Unrar path is incorrect or permissions are incorrect please edit your torrentexpander_settings.ini file or edit your permissions\n"; fi; quit_on_error="yes"; fi

if [ ! -x "$unzip_bin" ]; then echo "Your unzip path is incorrect or permissions are incorrect please edit your torrentexpander_settings.ini file or edit your permissions" >> "$errors_file"; if [ "$has_display" == "yes" ]; then echo -e "\nYour Unzip path is incorrect or permissions are incorrect please edit your torrentexpander_settings.ini file or edit your permissions\n"; fi; quit_on_error="yes"; fi

if [ ! -x "$wget_curl" ] && [[ "$imdb_poster" == "yes" || "$imdb_nfo" == "yes" || "$imdb_fanart" == "yes" ]]; then echo "Path to wget or curl is incorrect - IMDB features will be disabled" >> "$errors_file"; if [ "$has_display" == "yes" ]; then echo "Path to wget or curl is incorrect - IMDB features will be disabled"; fi; imdb_poster="no" && imdb_nfo="no" && imdb_fanart="no"; fi

if [ ! -x "$mkvdts2ac3_bin" ] && [ "$dts_post" == "yes" ]; then echo "Path to mkvdts2ac3.sh is incorrect - DTS Post will be disabled" >> "$errors_file"; if [ "$has_display" == "yes" ]; then echo -e "\nPath to mkvdts2ac3.sh is incorrect - DTS Post will be disabled\n"; fi; dts_post="no"; fi

if [ ! -x "$ccd2iso_bin" ] && [ "$img_post" == "yes" ]; then echo "Path to ccd2iso is incorrect - IMG to ISO Post will be disabled" >> "$errors_file"; if [ "$has_display" == "yes" ]; then echo -e "\nPath to ccd2iso is incorrect - IMG to ISO Post will be disabled\n"; fi; img_post="no"; fi

if [ ! -x "$torrent_daemon_bin" ] && [ "$destructive_mode" == "yes" ] && [ "$remove_torrent_from_client" == "yes" ]; then echo "Path to your torrent_daemon_bin is incorrect - Your torrent will not be removed from your torrent client" >> "$errors_file"; auto_delete_torrent="no"; fi

if [ ! -x "$all_files_script" ] && [ ! -x "$(which "$all_files_script")" ] && [ "$all_files_script_enabled" == "yes" ]; then echo "Path to your all_files_script is incorrect - This feature will be disabled" >> "$errors_file"; if [ "$has_display" == "yes" ]; then echo -e "\nPath to your all_files_script is incorrect - This feature will be disabled\n"; fi; all_files_script_enabled="no"; fi

if [ ! -x "$processed_torrent_script" ] && [ ! -x "$(which "$processed_torrent_script")" ] && [ "$processed_torrent_script_enabled" == "yes" ]; then echo "Path to your processed_torrent_script is incorrect - This feature will be disabled" >> "$errors_file"; if [ "$has_display" == "yes" ]; then echo -e "\nPath to your processed_torrent_script is incorrect - This feature will be disabled\n"; fi; processed_torrent_script_enabled="no"; fi

if [ ! -x "$post_run_script" ] && [ ! -x "$(which "$post_run_script")" ] && [ "$post_run_script_enabled" == "yes" ]; then echo "Path to your post_run_script is incorrect - This feature will be disabled" >> "$errors_file"; if [ "$has_display" == "yes" ]; then echo -e "\nPath to your post_run_script is incorrect - This feature will be disabled\n"; fi; post_run_script_enabled="no"; fi

if [[ "$supported_extensions_rev" == *rar* ]] || [[ "$tv_show_extensions_rev" == *rar* ]] || [[ "$movies_extensions_rev" == *rar* ]] || [[ "$music_extensions_rev" == *rar* ]] || [[ "$supported_extensions_rev" == *zip* ]] || [[ "$tv_show_extensions_rev" == *zip* ]] || [[ "$movies_extensions_rev" == *zip* ]] || [[ "$music_extensions_rev" == *zip* ]]; then echo "Your supported file extensions are incorrect please edit your torrentexpander_settings.ini file" >> "$errors_file"; if [ "$has_display" == "yes" ]; then echo "Your supported file extensions are incorrect please edit your torrentexpander_settings.ini file"; fi; quit_on_error="yes"; fi

# If in third_party_log mode we turn tv_shows_post, music_post and movies_post from move to copy mode.
if [[ "$third_party_log" != "no" && -f "$third_party_log" ]] || [[ "$processed_torrent_script_enabled" != "no" && -x "$processed_torrent_script" ]] || [[ "$processed_torrent_script_enabled" != "no" && -x "$(which "$processed_torrent_script")" ]]; then
	if [ "$tv_shows_post" != "no" ]; then 
		tv_shows_post="copy";
	fi
	if [ "$music_post" != "no" ]; then
		music_post="copy";
	fi
	if [ "$movies_post" != "no" ]; then
		movies_post="copy";
	fi
fi

if [ "$quit_on_error" == "yes" ]; then if [ "$has_display" == "yes" ]; then echo -e "\n\nThere's something wrong with your settings. Please review them now." && read -p "" && "$text_editor_bin" "$settings_file" && echo -e "\n\nYou're done with your setup\nThis script will exit now\nIf you need to edit your settings again just run $script_path/torrentexpander.sh -c"; elif [ "$update_mode" != "yes" ]; then exit; fi; fi


##################################################################################

# Starting to count steps in the script. Used only if there is a display
step_number=0

##################### CHECKING IF SCRIPT IS ALREADY RUNNING ######################
script_notif="torrentexpander is running"
log_file="$(echo "$destination_folder$script_notif")"

# Wait up to 240 x 15 seconds if the script is already running
count=0
while [ -f "$log_file" ]; do
	if [ "$has_display" == "yes" ]; then echo "Waiting for another instance of the script to end . . . . . ."; fi
	sleep 15; count=$(( count + 1 )); if [[ $count -gt 240 ]]; then rm "$log_file" && exit; fi
done

# Generating log file that will be used all along the script
if [ ! -f "$log_file" ]; then
	touch "$log_file"
fi


##################################################################################

if [ ! -d "$temp_directory" ]; then echo "Your temp folder path is incorrect please edit your torrentexpander_settings.ini file" >> "$errors_file"; if [ "$has_display" == "yes" ]; then echo -e "\nYour temp folder path is incorrect please edit your torrentexpander_settings.ini file\n"; fi; quit_on_error="yes"; fi
if [ -d "$temp_folder" ]; then echo "Temp folder already exists. Please delete it or edit your torrentexpander_settings.ini file" >> "$errors_file"; if [ "$has_display" == "yes" ]; then echo -e "\nTemp folder already exists. Please delete it or edit your torrentexpander_settings.ini file\n"; fi; quit_on_error="yes"; fi
if [[ ! -w "$temp_directory" ]]; then echo "Permissions on your temp folder are incorrect please edit your torrentexpander_settings.ini file or your permissions for this folder" >> "$errors_file"; if [ "$has_display" == "yes" ]; then echo -e "\nPermissions on your temp folder are incorrect please edit your torrentexpander_settings.ini file or your permissions for this folder\n"; fi; quit_on_error="yes"; fi

# Creating temp folder
mkdir -p "$temp_folder"

if [[ ! -w "$temp_folder" ]]; then
	echo "Permissions on your temp folder are incorrect please edit your torrentexpander_settings.ini file or your permissions for this folder" >> "$errors_file"
	if [ "$has_display" == "yes" ]; then echo "Permissions on your temp folder are incorrect please edit your torrentexpander_settings.ini file or your permissions for this folder"; fi
	quit_on_error="yes"
fi

if [ "$quit_on_error" == "yes" ]; then if [ "$has_display" == "yes" ]; then echo -e "\n\nThere's something wrong with your settings. Please review them now." && read -p "" && "$text_editor_bin" "$settings_file" && echo -e "\n\nYou're done with your setup\nThis script will exit now\nIf you need to edit your settings again just run $script_path/torrentexpander.sh -c"; elif [ "$update_mode" != "yes" ]; then exit; fi; fi


############################# SCRIPT AUTO UPDATE #################################
if [ "$update_mode" == "yes" ] && [ -t 1 ]; then has_display="yes"; fi
date_today=$(($(date "+%Y" | sed 's/^0*//')*365+$(date "+%m" | sed 's/^0*//')*30+$(date "+%d" | sed 's/^0*//')))
if [ ! "$last_update" ]; then last_update=0; fi

if [[ "$wget_curl" == *wget* || "$wget_curl" == *curl* ]] && [[ "$auto_update_script" == "daily" && $last_update -lt $(($date_today-1)) ]] || [[ "$auto_update_script" == "weekly" && $last_update -lt $(($date_today-7)) ]] || [[ "$auto_update_script" == "monthly" && $last_update -lt $(($date_today-30)) ]] || [ "$update_mode" == "yes" ]; then
	if [ "$has_display" == "yes" ]; then step_number=$(( $step_number + 1 )) && echo -e "Step $step_number : Updating Torrentexpander\n\n";  fi
	if [[ "$wget_curl" == *wget* ]]; then
		rel_cont=`echo "$("$wget_curl" -q "http://code.google.com/p/torrentexpander/source/browse/trunk" -O -; wait)"`;
	elif [[ "$wget_curl" == *curl* ]]; then
		rel_cont=`echo "$("$wget_curl" -silent -i "http://code.google.com/p/torrentexpander/source/browse/trunk"; wait)"`;
	fi
	release_vers="$(echo "$rel_cont" | egrep "trunk/torrentexpander.sh" | egrep ">[0-9][0-9][0-9]<" | sed "s;.*href=.trunk/torrentexpander.sh.>\([0-9][0-9][0-9]\)<.*;\1;")"
	if [[ $current_version -eq $release_vers ]]; then
		if [[ "$has_display" == "yes" ]]; then echo -e  "Torrentexpander is up to date\n\n"; fi
		if [[ "$gnu_sed_available" != "yes" ]]; then sed -i '' "/last_update=/d" "$settings_file"; fi
		if [[ "$gnu_sed_available" == "yes" ]]; then sed -i "/last_update=/d" "$settings_file"; fi
		echo "last_update=$date_today" >> "$settings_file"
	fi
	if [[ "$release_vers" && ! "$current_version" ]] || [[ "$release_vers" && $current_version -lt $release_vers ]]; then
		if [[ "$has_display" == "yes" ]]; then echo -e "A new version of Torrentexpander is available.\n\nDownloading it right now\n\n"; fi
		if [[ "$wget_curl" == *wget* ]]; then
			"$wget_curl" -q "http://torrentexpander.googlecode.com/svn/trunk/torrentexpander.sh" -O "$temp_folder_without_slash/new_script"; wait;
		elif [[ "$wget_curl" == *curl* ]]; then
			"$wget_curl" -# -C - -o "$temp_folder_without_slash/new_script" "http://torrentexpander.googlecode.com/svn/trunk/torrentexpander.sh" > /dev/null 2>&1; wait;
		fi
		if [ "$(cat "$temp_folder_without_slash/new_script" | grep "# REQUIRED SOFTWARE #")" ]; then
			if [[ "$has_display" == "yes" ]]; then echo -e "A new version of Torrentexpander has been downloaded.\nNow installing\n\n"; fi
			if [[ "$check_settings" != *urrent_version=* ]]; then echo "current_version=$release_vers" >> "$settings_file"; fi
			if [[ "$last_update" != *ast_update=* ]]; then echo "last_update=$date_today" >> "$settings_file"; fi
			if [[ $current_version -lt $release_vers ]]; then
				if [[ "$gnu_sed_available" != "yes" ]]; then sed -i '' "/current_version=/d" "$settings_file"; fi
				if [[ "$gnu_sed_available" == "yes" ]]; then sed -i "/current_version=/d" "$settings_file"; fi
				echo "current_version=$release_vers" >> "$settings_file"
				if [[ "$gnu_sed_available" != "yes" ]]; then sed -i '' "/last_update=/d" "$settings_file"; fi
				if [[ "$gnu_sed_available" == "yes" ]]; then sed -i "/last_update=/d" "$settings_file"; fi
				echo "last_update=$date_today" >> "$settings_file"
			fi
			if [[ "$has_display" == "yes" ]] && [ "$silent_mode" != "yes" ]; then echo -e "Torrentexpander is gonna restart now\n\n"; fi
			cat "$temp_folder_without_slash/new_script" > "$script_path/torrentexpander.sh"; wait;
			rm -rf "$temp_folder"
			rm -f "$log_file"
			export script_updated="yes"
			if [ "$update_mode" != "yes" ] && [ "$silent_mode" != "yes" ]; then . "$script_path/torrentexpander.sh" "$torrent" "$destination_folder";
			elif [ "$update_mode" != "yes" ] && [ "$silent_mode" == "yes" ]; then . "$script_path/torrentexpander.sh" "$torrent" "$destination_folder" -c;
			fi
			sleep 5
			exit
		fi
	fi
	if [ "$update_mode" == "yes" ]; then rm -rf "$temp_folder" && rm -f "$log_file" && exit; fi
fi

silent_mode="yes"

##################################################################################


## Expanding and copying folders to the temp folder
if [ "$has_display" == "yes" ]; then step_number=$(( $step_number + 1 )) && echo "Step $step_number : Expanding / moving content of the torrent";  fi
for item in $(if [[ "$current_folder" ]]; then find "$current_folder" -type d -follow; else echo "$torrent"; fi); do
	# Don t bother with Mac OS X invisible files
	if [[ "$item" == */.AppleDouble ]] || [[ "$item" == */._* ]] || [[ "$item" == */.DS_Store* ]]; then
		echo "" > /dev/null 2>&1
	# Fetch .rar and .001 rar files
	elif [[ "$(ls "$item" | egrep -i "\.rar$|\.001$")" ]]; then
		# Find the right .rar file
		if [[ "$(ls "$item" | egrep -i "part001\.rar$")" ]]; then rarFile=`ls "$item" | egrep -i "part001\.rar$"` && searchPath="$item/$rarFile";
		elif [[ "$(ls "$item" | egrep -i "part01\.rar$")" ]]; then rarFile=`ls "$item" | egrep -i "part01\.rar$"` && searchPath="$item/$rarFile";
		elif [[ "$(ls "$item" | egrep -i "part1\.rar$")" ]]; then rarFile=`ls "$item" | egrep -i "part1\.rar$"` && searchPath="$item/$rarFile";
		elif [[ -d "$item" && "$(ls "$item" | egrep -i "\.rar$")" ]]; then searchPath=`find "$item" -maxdepth 1 ! -name "._*" -type f -follow | egrep -i "\.rar$"`;
		elif [[ "$(echo "$torrent" | egrep -i "\.rar$" )" ]]; then searchPath=`echo "$item" | egrep -i "\.rar$"`;
		# switch back to the .001 file
		elif [[ "$(ls "$item" | egrep -i "\.001$")" ]]; then rarFile=`ls "$item" | egrep -i "\.001$"` && searchPath="$item/$rarFile";
		fi
		# use unrar to unrar files. Use nice -n 15 if available. Output will be displayed if possible
		if [[ "$unrar_bin" == *unrar* ]] && [ "$nice_available" == "yes" ] && [ "$has_display" == "yes" ]; then for f in $(echo -e "$searchPath"); do nice -n 15 "$unrar_bin" x -y -o+ -p- `echo "$f"` "$temp_folder"; done
		elif [[ "$unrar_bin" == *unrar* ]] && [ "$nice_available" == "yes" ]; then for f in $(echo -e "$searchPath"); do nice -n 15 "$unrar_bin" x -y -o+ -p- `echo "$f"` "$temp_folder" > /dev/null 2>&1; done
		elif [[ "$unrar_bin" == *unrar* ]] && [ "$has_display" == "yes" ]; then for f in $(echo -e "$searchPath"); do "$unrar_bin" x -y -o+ -p- `echo "$f"` "$temp_folder" ; done
		elif [[ "$unrar_bin" == *unrar* ]]; then for f in $(echo -e "$searchPath"); do "$unrar_bin" x -y -o+ -p- `echo "$f"` "$temp_folder" > /dev/null 2>&1; done
		# use 7z to unrar files. Use nice -n 15 if available. Output will be displayed if possible
		elif [[ "$unrar_bin" == *7z* ]] && [ "$nice_available" == "yes" ] && [ "$has_display" == "yes" ]; then for f in $(echo -e "$searchPath"); do nice -15 "$unrar_bin" x -y `echo "$f"` -o"$temp_folder"; done
		elif [[ "$unrar_bin" == *7z* ]] && [ "$nice_available" == "yes" ]; then for f in $(echo -e "$searchPath"); do nice -15 "$unrar_bin" x -y `echo "$f"` -o"$temp_folder" > /dev/null 2>&1; done
		elif [[ "$unrar_bin" == *7z* ]] && [ "$has_display" == "yes" ]; then for f in $(echo -e "$searchPath"); do "$unrar_bin" x -y `echo "$f"` -o"$temp_folder"; done
		elif [[ "$unrar_bin" == *7z* ]]; then for f in $(echo -e "$searchPath"); do "$unrar_bin" x -y `echo "$f"` -o"$temp_folder" > /dev/null 2>&1; done
		fi
	# Fetch zip files
	elif [[ "$(ls $item | egrep -i "\.zip$")" ]]; then
		# use unzip to unzip files. Use nice -n 15 if available. Output will be displayed if possible
		if [[ -d "$item" && "$(ls "$item" | egrep -i "\.zip$")" ]]; then searchPath=`find "$item" -maxdepth 1 ! -name "._*" -type f -follow | egrep -i "\.zip$"`;
		elif [[ "$(echo "$item" | egrep -i "\.zip$" )" ]]; then searchPath=`echo "$item" | egrep -i "\.zip$"`;
		fi
		if [[ "$unzip_bin" == *unzip* ]] && [ "$nice_available" == "yes" ] && [ "$has_display" == "yes" ]; then for f in $(echo -e "$searchPath"); do nice -n 15 "$unzip_bin" -o -j `echo "$f"` -d "$temp_folder"; done
		elif [[ "$unzip_bin" == *unzip* ]] && [ "$nice_available" == "yes" ]; then for f in $(echo -e "$searchPath"); do nice -n 15 "$unzip_bin" -o -j `echo "$f"` -d "$temp_folder" > /dev/null 2>&1; done
		elif [[ "$unzip_bin" == *unzip* ]] && [ "$has_display" == "yes" ]; then for f in $(echo -e "$searchPath"); do "$unzip_bin" -o -j `echo "$f"` -d "$temp_folder"; done
		elif [[ "$unzip_bin" == *unzip* ]]; then for f in $(echo -e "$searchPath"); do "$unzip_bin" -o -j `echo "$f"` -d "$temp_folder" > /dev/null 2>&1; done
		# use 7z to unzip files. Use nice -n 15 if available. Output will be displayed if possible
		elif [[ "$unzip_bin" == *7z* ]] && [ "$nice_available" == "yes" ] && [ "$has_display" == "yes" ]; then for f in $(echo -e "$searchPath"); do nice -n 15 "$unzip_bin" x -y `echo "$f"` -o"$temp_folder"; done
		elif [[ "$unzip_bin" == *7z* ]] && [ "$nice_available" == "yes" ]; then for f in $(echo -e "$searchPath"); do nice -n 15 "$unzip_bin" x -y `echo "$f"` -o"$temp_folder" > /dev/null 2>&1; done
		elif [[ "$unzip_bin" == *7z* ]] && [ "$has_display" == "yes" ]; then for f in $(echo -e "$searchPath"); do "$unzip_bin" x -y `echo "$f"` -o"$temp_folder"; done
		elif [[ "$unzip_bin" == *7z* ]]; then for f in $(echo -e "$searchPath"); do "$unzip_bin" x -y `echo "$f"` -o"$temp_folder" > /dev/null 2>&1; done
		fi
	fi
done

for item in $(if [[ "$current_folder" ]]; then find "$current_folder" -type d -follow; else echo "$torrent"; fi); do
	# Don t bother with Mac OS X invisible files
	if [[ "$item" == */.AppleDouble ]] || [[ "$item" == */._* ]] || [[ "$item" == */.DS_Store* ]]; then
		echo "" > /dev/null 2>&1
	# Now fetch all other files and copy them to the temp folder, or move them if in destructive mode
	elif [[ "$(ls $item | egrep -i -v "\.[0-9][0-9][0-9]$|\.r[0-9][0-9]$|\.rar$|\.001$|\.zip$")" ]]; then
		# 
		if [[ -d "$item" && "$(ls "$item" | egrep -i -v "\.[0-9][0-9][0-9]$|\.r[0-9][0-9]$|\.rar$|\.001$|\.zip$")" ]]; then otherFiles=`find "$item" -maxdepth 1 ! -name "._*" -type f -follow | egrep -i -v "\.[0-9][0-9][0-9]$|\.r[0-9][0-9]$|\.rar$|\.001$|\.zip$"`
		dest_path=`echo "$temp_folder$(echo "$item" | sed "s;.*/;;g")/"`
		elif [[ "$(echo "$item" | egrep -i -v "\.[0-9][0-9][0-9]$|\.r[0-9][0-9]$|\.rar$|\.001$|\.zip$")" ]]; then otherFiles=`echo "$item" | egrep -i -v "\.[0-9][0-9][0-9]$|\.r[0-9][0-9]$|\.rar$|\.001$|\.zip$"`
		dest_path=`echo "$temp_folder"`
		fi
		for f in $(echo -e "$otherFiles"); do
			if [ ! -d "$dest_path" ]; then mkdir -p "$dest_path"; fi
			otherFile=`echo "$f"`
			count=1
			dest_path_2=`echo "$dest_path$(basename "$otherFile")"`
			while [ -f "$dest_path_2" ]; do
				if [[ count -eq 1 ]]; then
					dest_path_2=`echo "$dest_path$(echo "$(basename "$otherFile")")"`;
				else
					dest_path_2=`echo "$dest_path$(echo "$(basename "$otherFile")" | sed 's/\(.*\)\..*/\1/') [$count]$(echo "$otherFile" | sed 's;.*\.;.;')"`;
				fi
				count=$(( count + 1 ))
			done
			if [[ "$nice_available" == "yes" && "$destructive_mode" != "yes" ]]; then nice -n 15 cp -f "$otherFile" "$dest_path_2";
			elif [[ "$nice_available" != "yes" && "$destructive_mode" != "yes" ]]; then cp -f "$otherFile" "$dest_path_2";
			elif [ "$destructive_mode" == "yes" ]; then nice -n 15 mv -f "$otherFile" "$dest_path_2";
			fi
		done
	fi
done


## If destructive_mode is enabled, remove original torrent
cd "$destination_folder"
if [[ "$has_display" == "yes" && "$destructive_mode" == "yes" ]]; then
	step_number=$(( $step_number + 1 ));
	echo "Step $step_number : Deleting original torrent";
fi

# Make sure torrentexpander did not fail
if [[ "$destructive_mode" == "yes" ]] && [[ -d "$current_folder" || -f "$torrent" ]]; then
	temp_size=$(du -a -c "$temp_folder" | sed -n '$p' | sed "s;\([0-9]*\)\t.*;\1;")
	count=0 && files=$(( $count + $(find "$temp_folder_without_slash" -type f | wc -l) ))
	if [[ "$current_folder" ]]; then torrent_size=$(du -a -c "$current_folder" | sed -n '$p' | sed "s;\([0-9]*\)\t.*;\1;"); else echo torrent_size=$(du -a -c "$torrent" | sed -n '$p' | sed "s;\([0-9]*\)\t.*;\1;"); fi
	temp_size=$(( $temp_size + ( $temp_size / 10 ) ))
	if [ "$temp_size" -lt "$torrent_size" ] || [[ $files -eq 0 ]]; then destructive_mode="no"; fi
fi

# If in GUI mode, we ask the user if he wants to remove this torrent from his torrent client
user_confirm_removal=0
if [ "$has_display" == "yes" ] && [[ "$destructive_mode" == "yes" && "$torrent_name" ]] && [ -x "$torrent_daemon_bin" ]; then
	while [[ "$user_confirm_removal" != "1" ]] && [[ "$user_confirm_removal" != "2" ]]; do
		echo -e "\n\nDo you want to remove this torrent from your torrent client ?\n\n1) Yes, Please\n2) No, Thank You\n\n"
		read user_confirm_removal
		if [[ "$user_confirm_removal" != "1" ]] && [[ "$user_confirm_removal" != "2" ]]; then
			echo -e "\n\nUh-oh, I cannot understand your answer, please try again"
		elif [[ "$user_confirm_removal" == "1" ]] || [[ "$user_confirm_removal" == "2" ]]; then
			echo -e "\n\nDuly noted\n\n"
		fi
	done
	if [ "$user_confirm_removal" == "1" ]; then
		remove_torrent_from_client="yes";
	fi
	if [ "$user_confirm_removal" == "2" ]; then
		remove_torrent_from_client="no";
	fi
fi

# Trying to remove torrent from torrent client if destructive_mode is activated
if [[ "$destructive_mode" == "yes" && "$torrent_name" ]] && [[ -x "$torrent_daemon_bin" && "$(echo "$torrent_daemon_bin" | grep "transmission-remote")" && "$torrent_daemon_port" ]] && [ "$remove_torrent_from_client" == "yes" ]; then
	# Getting torrent ID
	if [[ ! "$torrent_daemon_login" ]] || [[ ! "$torrent_daemon_password" ]]; then
		daemon_ip="localhost:$torrent_daemon_port"
		torrent_id=$("$torrent_daemon_bin" "$daemon_ip" -l > /dev/null 2>&1 | grep "$torrent_name" | sed "s;^ \([0-9]*\)   .*;\1;")
	elif [[ "$torrent_daemon_login" ]] && [[ "$torrent_daemon_password" ]]; then
		daemon_ip="localhost:$torrent_daemon_port"
		daemon_l_p="$torrent_daemon_login:$torrent_daemon_password"
		torrent_id=$("$torrent_daemon_bin" "$daemon_ip" -n "$daemon_l_p" -l > /dev/null 2>&1 | grep "$torrent_name" | sed "s;^ *\([0-9]*\).*$;\1;")
	fi
	# Pausing and deleting torrent
	if [[ "$torrent_id" ]]; then
		if [[ ! "$torrent_daemon_login" ]] || [[ ! "$torrent_daemon_password" ]]; then
			if [[ "$has_display" == "yes" ]]; then
				"$torrent_daemon_bin" "$daemon_ip" -t "$torrent_id" -S && "$torrent_daemon_bin" "$daemon_ip" -t "$torrent_id" --remove-and-delete
			else
				"$torrent_daemon_bin" "$daemon_ip" -t "$torrent_id" -S > /dev/null 2>&1 && "$torrent_daemon_bin" "$daemon_ip" -t "$torrent_id" --remove-and-delete > /dev/null 2>&1
			fi
		elif [[ "$torrent_daemon_login" ]] && [[ "$torrent_daemon_password" ]]; then
			if [[ "$has_display" == "yes" ]]; then
				"$torrent_daemon_bin" "$daemon_ip" -n "$daemon_l_p" -t "$torrent_id" -S && "$torrent_daemon_bin" "$daemon_ip" -n "$daemon_l_p" -t "$torrent_id" --remove-and-delete
			else
				"$torrent_daemon_bin" "$daemon_ip" -n "$daemon_l_p" -t "$torrent_id" -S > /dev/null 2>&1 && "$torrent_daemon_bin" -n "$daemon_l_p" "$daemon_ip" -t "$torrent_id" --remove-and-delete > /dev/null 2>&1
			fi
		fi
	fi
elif [[ "$destructive_mode" == "yes" && "$torrent_name" ]] && [[ -x "$torrent_daemon_bin" && "$(echo "$torrent_daemon_bin" | grep "xmlrpc")" ]] && [ "$remove_torrent_from_client" == "yes" ]; then
	# Getting torrent IDs
	if [[ ! "$torrent_daemon_login" ]] || [[ ! "$torrent_daemon_password" ]]; then
		daemon_ip="localhost"
		torrent_ids=$("$torrent_daemon_bin" "$daemon_ip" download_list | grep "Index" | sed "s;.*Index.*String.*'\(.*\)'.*;\1;g")
	elif [[ "$torrent_daemon_login" ]] && [[ "$torrent_daemon_password" ]]; then
		daemon_ip="localhost"
		torrent_ids=$("$torrent_daemon_bin" -u "$torrent_daemon_login" -p "$torrent_daemon_password" "$daemon_ip" download_list | grep "Index" | sed "s;.*Index.*String.*'\(.*\)'.*;\1;g")
	fi
	# Getting torrent ID
	for id in $(echo -e "$torrent_ids"); do
		if [[ ! "$torrent_daemon_login" ]] || [[ ! "$torrent_daemon_password" ]]; then
			daemon_ip="localhost"
			torrent_id=$("$torrent_daemon_bin" "$daemon_ip" d.get_name "$id" | grep "String" | sed "s;.*String.*'\(.*\)';\1;g")
		elif [[ "$torrent_daemon_login" ]] && [[ "$torrent_daemon_password" ]]; then
			daemon_ip="localhost"
			torrent_id=$("$torrent_daemon_bin" -u "$torrent_daemon_login" -p "$torrent_daemon_password" "$daemon_ip" d.get_name "$id" | grep "String" | sed "s;.*String.*'\(.*\)';\1;g")
		fi
		# Pausing and deleting torrent
		if [[ "$id" ]] && [ "$torrent_id" == "$torrent_name" ]; then
			if [[ ! "$torrent_daemon_login" ]] || [[ ! "$torrent_daemon_password" ]]; then
				if [[ "$has_display" == "yes" ]]; then
					"$torrent_daemon_bin" "$daemon_ip" d.close "$id" && "$torrent_daemon_bin" "$daemon_ip" d.erase "$id"
				else
					"$torrent_daemon_bin" "$daemon_ip" d.close "$id" > /dev/null 2>&1 && "$torrent_daemon_bin" "$daemon_ip" d.erase "$id" > /dev/null 2>&1
				fi
			elif [[ "$torrent_daemon_login" ]] && [[ "$torrent_daemon_password" ]]; then
				if [[ "$has_display" == "yes" ]]; then
					"$torrent_daemon_bin" -u "$torrent_daemon_login" -p "$torrent_daemon_password" "$daemon_ip" d.close "$id" && "$torrent_daemon_bin" -u "$torrent_daemon_login" -p "$torrent_daemon_password" "$daemon_ip" d.erase "$id"
				else
					"$torrent_daemon_bin" -u "$torrent_daemon_login" -p "$torrent_daemon_password" "$daemon_ip" d.close "$id" > /dev/null 2>&1 && "$torrent_daemon_bin" -u "$torrent_daemon_login" -p "$torrent_daemon_password" "$daemon_ip" d.erase "$id" > /dev/null 2>&1
				fi
			fi
		fi
	done
fi


# If torrent client daemon cannot be controlled, we ll remove the torrent anyway
if [[ "$destructive_mode" == "yes" && "$torrent" && -f "$torrent" ]]; then
        rm -f "$torrent";
elif [[ "$destructive_mode" == "yes" && "$current_folder" && -d "$current_folder" ]]; then
        rm -rf "$current_folder";
fi


## If .rar archives within archives - Expanding to the temp folder
for item in $(find "$temp_folder_without_slash" -type d); do
	if [[ "$item" == */.AppleDouble ]] || [[ "$item" == */._* ]] || [[ "$item" == */.DS_Store* ]]; then
		echo "" > /dev/null 2>&1
	elif [[ "$(ls "$item" | egrep -i "\.rar$")" ]]; then
		# Fetch .rar that were previously rared
		if [[ "$(ls "$item" | egrep -i "part001\.rar$")" ]]; then rarFile=`ls "$item" | egrep -i "part001\.rar$"` && searchPath="$item/$rarFile";
		elif [[ "$(ls "$item" | egrep -i "part01\.rar$")" ]]; then rarFile=`ls "$item" | egrep -i "part01\.rar$"` && searchPath="$item/$rarFile";
		elif [[ "$(ls "$item" | egrep -i "part1\.rar$")" ]]; then rarFile=`ls "$item" | egrep -i "part1\.rar$"` && searchPath="$item/$rarFile";
		elif [[ -d "$item" && "$(ls "$item" | egrep -i "\.rar$")" ]]; then searchPath=`find "$item" -maxdepth 1 ! -name "._*" -type f -follow | egrep -i "\.rar$"`;
		elif [[ "$(echo "$torrent" | egrep -i "\.rar$" )" ]]; then searchPath=`echo "$item" | egrep -i "\.rar$"`;
		elif [[ "$(ls "$item" | egrep -i "\.001$")" ]]; then rarFile=`ls "$item" | egrep -i "\.001$"` && searchPath="$item/$rarFile";
		fi
		# use unrar to unrar files. Use nice -n 15 if available. Output will be displayed if possible
		if [[ "$unrar_bin" == *unrar* ]] && [ "$nice_available" == "yes" ] && [ "$has_display" == "yes" ]; then for f in $(echo -e "$searchPath"); do nice -n 15 "$unrar_bin" x -y -o+ -p- `echo "$f"` "$item"; done
		elif [[ "$unrar_bin" == *unrar* ]] && [ "$nice_available" == "yes" ]; then for f in $(echo -e "$searchPath"); do nice -n 15 "$unrar_bin" x -y -o+ -p- `echo "$f"` "$item" > /dev/null 2>&1; done
		elif [[ "$unrar_bin" == *unrar* ]] && [ "$has_display" == "yes" ]; then for f in $(echo -e "$searchPath"); do "$unrar_bin" x -y -o+ -p- `echo "$f"` "$item"; done
		elif [[ "$unrar_bin" == *unrar* ]]; then for f in $(echo -e "$searchPath"); do "$unrar_bin" x -y -o+ -p- `echo "$f"` "$item" > /dev/null 2>&1; done
		# use 7z to unrar files. Use nice -n 15 if available. Output will be displayed if possible
		elif [[ "$unrar_bin" == *7z* ]] && [ "$nice_available" == "yes" ] && [ "$has_display" == "yes" ]; then for f in $(echo -e "$searchPath"); do nice -15 `echo "$f"` x -y "$searchPath" -o"$item"; done
		elif [[ "$unrar_bin" == *7z* ]] && [ "$nice_available" == "yes" ]; then for f in $(echo -e "$searchPath"); do nice -15 "$unrar_bin" x -y `echo "$f"` -o"$item" > /dev/null 2>&1; done
		elif [[ "$unrar_bin" == *7z* ]] && [ "$has_display" == "yes" ]; then for f in $(echo -e "$searchPath"); do "$unrar_bin" x -y `echo "$f"` -o"$item"; done
		elif [[ "$unrar_bin" == *7z* ]]; then for f in $(echo -e "$searchPath"); do "$unrar_bin" x -y `echo "$f"` -o"$item" > /dev/null 2>&1; done
		fi
	fi
done

## If .zip archives within archives - Expanding to the temp folder
for item in $(find "$temp_folder_without_slash" -type d); do
	if [[ "$item" == */.AppleDouble ]] || [[ "$item" == */._* ]] || [[ "$item" == */.DS_Store* ]]; then
		echo "" > /dev/null 2>&1
	elif [[ "$(ls "$item" | egrep -i "\.zip$")" ]]; then
		searchPath=`find "$item" -maxdepth 1 ! -name "._*" -type f -follow | egrep -i "\.zip$"`;
		# use unzip to unzip files. Use nice -n 15 if available. Output will be displayed if possible
		if [[ "$unzip_bin" == *unzip* ]] && [ "$nice_available" == "yes" ] && [ "$has_display" == "yes" ]; then for f in $(echo -e "$searchPath"); do nice -n 15 "$unzip_bin" -o -j `echo "$f"` -d "$item"; done
		elif [[ "$unzip_bin" == *unzip* ]] && [ "$nice_available" == "yes" ]; then for f in $(echo -e "$searchPath"); do nice -n 15 "$unzip_bin" -o -j `echo "$f"` -d "$item" > /dev/null 2>&1; done
		elif [[ "$unzip_bin" == *unzip* ]] && [ "$has_display" == "yes" ]; then for f in $(echo -e "$searchPath"); do "$unzip_bin" -o -j `echo "$f"` -d "$item"; done
		elif [[ "$unzip_bin" == *unzip* ]]; then for f in $(echo -e "$searchPath"); do "$unzip_bin" -o -j `echo "$f"` -d "$item" > /dev/null 2>&1; done
		# use 7z to unzip files. Use nice -n 15 if available. Output will be displayed if possible
		elif [[ "$unzip_bin" == *7z* ]] && [ "$nice_available" == "yes" ] && [ "$has_display" == "yes" ]; then for f in $(echo -e "$searchPath"); do nice -n 15 "$unzip_bin" x -y `echo "$f"` -o"$item"; done
		elif [[ "$unzip_bin" == *7z* ]] && [ "$nice_available" == "yes" ]; then for f in $(echo -e "$searchPath"); do nice -n 15 "$unzip_bin" x -y `echo "$f"` -o"$item" > /dev/null 2>&1; done
		elif [[ "$unzip_bin" == *7z* ]] && [ "$has_display" == "yes" ]; then for f in $(echo -e "$searchPath"); do "$unzip_bin" x -y `echo "$f"` -o"$item"; done
		elif [[ "$unzip_bin" == *7z* ]]; then for f in $(echo -e "$searchPath"); do "$unzip_bin" x -y `echo "$f"` -o"$item" > /dev/null 2>&1; done
		fi
	fi
done

## Delete Mac OS X invisible files and sample from temp folder
for item in $(find "$temp_folder_without_slash"); do
	item=`echo "$item"`
	if [[ "$item" == */.AppleDouble* ]] || [[ "$item" == */._* ]] || [[ "$item" == */.DS_Store* ]]; then rm -rf "$item"
	elif [[ "$(echo "$item" | egrep -i "^sample[^A-Za-z0-9_]" )" && "$(echo "$item" | egrep -i "\.avi$|\.mkv$|\.divx$|\.mp4$|\.ts$" )" ]] || [[ "$(echo "$item" | egrep -i "[^A-Za-z0-9_]sample[^A-Za-z0-9_]" )" && "$(echo "$item" | egrep -i "\.avi$|\.mkv$|\.divx$|\.mp4$|\.ts$" )" ]]; then rm -rf "$item"
	fi
done

## Count number of resulting files and disable optional functionalities if no supported file
count=0 && files=$(( $count + $(find "$temp_folder_without_slash" -type f | egrep -i "$supported_extensions_rev" | wc -l) ))


## No supported file, disable all optional features except for permissions and timestamp
if [[ $files -eq 0 ]]; then
	tv_shows_fix_numbering="no" && clean_up_filenames="no" && dts_post="no" && img_post="no" && wii_post="no" && tv_shows_post="no" && music_post="no" && movies_post="no" && imdb_poster="no" && imdb_nfo="no" && imdb_fanart="no" && debug_mode="no" && subtitles_handling="no" && repack_handling="no" && force_single_file_movies_folder="no" && disable_nmj_scan="no"
	count=0 && files=$(( $count + $(find "$temp_folder_without_slash" -type f | wc -l) ))
	if [[ $files -eq 0 ]]; then
		# No file at all something is wrong so we disable all features
		if [[ "$has_display" == "yes" ]]; then
			step_number=$(( $step_number + 1 ));
			echo "Step $step_number : Uh Oh, Something went wrong, I cannot continue";
		fi
		destructive_mode="no" && user_perm_post="no" && group_perm_post="no" && files_perm_post="no" && folder_perm_post="no" && edit_perm_as_sudo="no" && third_party_log="no" && reset_timestamp="no" && remove_torrent_from_client="no" && all_files_script_enabled="no" && processed_torrent_script_enabled="no" && post_run_script_enabled="no" && script_failed="yes"
	else
		# Unsupported files only so we will only do the bare minimum
		if [ ! "$folder_short" ]; then folder_short=`echo "$torrent" | sed 's/\(.*\)\..*/\1/' | sed 's;.*/;;g'`; fi
		for item in $(find "$temp_folder" -type f); do
			item=`echo "$item"`
			mkdir -p "$temp_folder$folder_short/"
			if [ ! -f "$temp_folder$folder_short/$(basename "$item")" ]; then
				mv -f "$item" "$temp_folder$folder_short/"
			fi
			echo "$item" >> "$log_file"
		done
	fi
fi


## If only one resulting file rename it according to the initial torrent
if [[ $files -eq 1 ]]; then
	if [ ! "$folder_short" ]; then folder_short=`echo "$torrent" | sed 's/\(.*\)\..*/\1/' | sed 's;.*/;;g'`; fi
	item=`echo "$(find "$temp_folder_without_slash" -type f | egrep -i "$supported_extensions_rev")"`;
	extension=`echo "$item" | sed 's;.*\.;.;'`;
	if [[ "$item" != "$temp_folder$folder_short$extension" ]]; then mv "$item" "$temp_folder$folder_short$extension"; fi && echo "$temp_folder$folder_short$extension" >> "$log_file"
	subtitles_dest=`echo "$subtitles_directory/$(basename "$item")"`
	already_subtitles=`echo "$(echo "$item" | sed 's/\(.*\)\..*/\1\.srt/')"`
	if [[ "$subtitles_mode" != "yes" && "$subtitles_handling" == "yes" && ! -f "$already_subtitles" && "$(echo "$item" | egrep -i "\.avi$|\.mkv$|\.divx$|\.mp4$|\.ts$")" ]]; then if [ ! -d "$subtitles_directory" ]; then mkdir -p "$subtitles_directory"; fi ; echo "$(basename "$item")" > "$subtitles_dest"; fi
	# Reset folder_short variable because no folder will be generated
	folder_short=""
fi

## If more than one supported file, create folder named as the initial one and move the resulting files there
if [[ $files -gt 1 ]]; then for directory in $(find "$temp_folder_without_slash" -type d); do
	# Archive that contains several files. We ll use the original name of the archive
	if [ ! "$folder_short" ]; then folder_short=`echo "$torrent" | sed 's/\(.*\)\..*/\1/' | sed 's;.*/;;g'`; fi
	# For audio files, we ll change things a bit, in order to group album tracks from an audio pack
	if [ "$(ls $directory | egrep -i "$music_extensions_rev" )" ]; then
		audioFiles=`ls $directory | egrep -i "$music_extensions_rev"`;
		for f in $(echo -e "$audioFiles"); do
			item=`echo "$directory/$f"`;
			depth=$(( $(echo "$directory/" | sed "s;$torrent_directory;;g" | sed "s;[^/];;g" | wc -c) - 1 ))
			if [[ $depth -eq 1 ]]; then destination_name="$temp_folder$folder_short/"; elif [[ $depth -gt 1 ]]; then destination_name="$temp_folder$folder_short/$(echo "$item" | sed "s;$temp_folder;;g" | sed "s;/; - ;g")"; fi
			mkdir -p "$temp_folder$folder_short/" && mv -f "$item" "$destination_name"
		done
	# We ll move all the other files to a directory named after the torrent
	elif [ "$(ls $directory | egrep -i "$supported_extensions_rev" )" ]; then
		otherFiles=`ls $directory | egrep -i "$supported_extensions_rev"`;
		if [ ! -f "$temp_folder$folder_short/$(basename $item)" ]; then
			for f in $(echo -e "$otherFiles"); do item=`echo "$directory/$f"`; mkdir -p "$temp_folder$folder_short/" && mv -f "$item" "$temp_folder$folder_short/"; done
		fi
	fi
done

## Generate dummy 0k video for later subtitles fetching if no subtitles is already available
for item in $(find "$temp_folder$folder_short" -type f | egrep -i "$supported_extensions_rev"); do
	subtitles_dest=`echo "$subtitles_directory/$(basename "$item")"`
	already_subtitles=`echo "$(echo "$item" | sed 's/\(.*\)\..*/\1\.srt/')"`
	if [[ "$subtitles_mode" != "yes" && "$subtitles_handling" == "yes" && ! -f "$already_subtitles" && "$(echo "$item" | egrep -i "\.avi$|\.mkv$|\.divx$|\.mp4$|\.ts$")" ]]; then if [ ! -d "$subtitles_directory" ]; then mkdir -p "$subtitles_directory"; fi ; echo "$(basename "$item")" > "$subtitles_dest"; fi
	echo "$item" >> "$log_file"
done
fi


######################### Optional functionalities ################################

# defining imdb_funct_on variable so that we don't have to ckeck 3 variables everytime
if [[ "$imdb_poster" == "yes" || "$imdb_nfo" == "yes" || "$imdb_fanart" == "yes" ]]; then imdb_funct_on="yes"; fi

# Adding the surrounding folder to the log file so that it can be renamed
if [[ "$folder_short" && "$tv_shows_fix_numbering" == "yes" ]] || [[ "$folder_short" && "$clean_up_filenames" == "yes" ]] || [[ "$folder_short" && "$imdb_funct_on" == "yes" ]]; then echo "$temp_folder$folder_short" >> "$log_file"; fi

## Try to solve TV Shown Numbering issues
if [[ "$has_display" == "yes" && "$tv_shows_fix_numbering" == "yes" && "$(cat "$log_file" | egrep -i "([. _-])([0-9])([0-9])([xX])([0-9])([0-9])([. _-])")" ]] || [[ "$has_display" == "yes" && "$tv_shows_fix_numbering" == "yes" && "$(cat "$log_file" | egrep -i "([. _-])([123456789])([xX])([0-9])([0-9])")" ]] || [[ "$has_display" == "yes" && "$tv_shows_fix_numbering" == "yes" && "$(cat "$log_file" | egrep -i "([. _-])([01])([0-9])([0-3])([0-9])([^pPiI])")" ]] || [[ "$has_display" == "yes" && "$tv_shows_fix_numbering" == "yes" && "$(cat "$log_file" | egrep -i ".([^eE])([12345689])([0123])([0-9])([^0123456789pPiI])")" ]]; then step_number=$(( $step_number + 1 )) && echo "Step $step_number : Trying to solve TV Shows numbering issues";  fi
# Looking for files that look like TV shows because they contain SxEE, SSEE, SEE 
if [[ "$tv_shows_fix_numbering" == "yes" && "$(cat "$log_file" | egrep -i "([. _-])([0-9])([0-9])([xX])([0-9])([0-9])([. _-])")" ]] || [[ "$tv_shows_fix_numbering" == "yes" && "$(cat "$log_file" | egrep -i "([. _-])([123456789])([xX])([0-9])([0-9])")" ]] || [[ "$tv_shows_fix_numbering" == "yes" && "$(cat "$log_file" | egrep -i "([. _-])([01])([0-9])([0-3])([0-9])([^pPiI])")" ]] || [[ "$tv_shows_fix_numbering" == "yes" && "$(cat "$log_file" | egrep -i ".([^eE])([12345689])([0123])([0-9])([^0123456789pPiI])")" ]]; then for line in $(cat "$log_file"); do
	item=`echo "$(basename "$line")"`;
	ren_file=`echo "$item"`;
	source=`echo "$line"`;
	# Looking for SSxEE pattern
	if [[ "$tv_shows_fix_numbering" == "yes" && "$(echo "$line" | egrep -i "([. _-])([0-9])([0-9])([xX])([0-9])([0-9])([. _-])")" ]] && [[ ! "$(echo "$line" | egrep -i "\.iso$|\.img$")" || ! "$(cat "$log_file" | egrep -i "\.dvd$")" ]] && [[ -d "$line" || "$(echo "$line" | egrep -i "$tv_show_extensions_rev")" ]]; then
		ren_file=`echo "$item" | sed 's;\(.*\)[. _-]\([0-9]\)\([0-9]\)\([xX]\)\([0-9]\)\([0-9]\)\([. _-]\);\1 S\2\3E\5\6\7;g'`;
	# Looking for SxEE pattern
	elif [[ "$tv_shows_fix_numbering" == "yes" && "$(echo "$line" | egrep -i "([. _-])([123456789])([xX])([0-9])([0-9])([. _-])")" ]] && [[ ! "$(echo "$line" | egrep -i "\.iso$|\.img$")" || ! "$(cat "$log_file" | egrep -i "\.dvd$")" ]] && [[ -d "$line" || "$(echo "$line" | egrep -i "$tv_show_extensions_rev")" ]]; then
		ren_file=`echo "$item" | sed 's;\(.*\)[. _-]\([123456789]\)\([xX]\)\([0-9]\)\([0-9]\)\([. _-]\);\1 S0\2E\4\5\6;g'`;
	# Looking for SSEE pattern
	elif [[ "$tv_shows_fix_numbering" == "yes" && "$(echo "$line" | egrep -i "([. _-])([01])([0-9])([0-3])([0-9])([^pPiI])")" ]] && [[ ! "$(echo "$line" | egrep -i "\.iso$|\.img$")" || ! "$(cat "$log_file" | egrep -i "\.dvd$")" ]] && [[ -d "$line" || "$(echo "$line" | egrep -i "$tv_show_extensions_rev")" ]]; then
		ren_file=`echo "$item" | sed 's;\(.*\)[. _-]\([01]\)\([0-9]\)\([0-3]\)\([0-9]\)\([^pPiI]\);\1 S\2\3E\4\5\6;g'`;
	# Looking for SEE pattern
	elif [[ "$tv_shows_fix_numbering" == "yes" && "$(echo "$line" | egrep -i ".([^eE])([12345689])([0123])([0-9])([^0123456789pPiI])")" ]] && [[ ! "$(echo "$line" | egrep -i "\.iso$|\.img$")" || ! "$(cat "$log_file" | egrep -i "\.dvd$")" ]] && [[ -d "$line" || "$(echo "$line" | egrep -i "$tv_show_extensions_rev")" ]]; then
		ren_file=`echo "$item" | sed 's;\(.*\)\(.\)\([^eE]\)\([12345689]\)\([0123]\)\([0-9]\)\([^0123456789pPiI]\);\1\2\3S0\4E\5\6\7;g'`;
	fi
	bis="_bis"
	ren_location=`echo "$(dirname "$source")/$ren_file"`;
	ren_temp_location=`echo "$(dirname "$source")/$ren_file$bis"`;
	source_bis=`echo "$line"`;
	source_ter=$(echo "$line" | sed "s;\([][]\);\\\\\1;g") && source_ter=`echo "$source_ter"`;
	ren_location_bis=$(echo "$ren_location" | sed "s;\([][)(]\);\\\\\1;g") && ren_location_bis=`echo "$ren_location_bis"`;
	# Displaying output if possible
	if [ "$has_display" == "yes" ] && [ "$item" != "$ren_file" ]; then echo "- Renaming $item to $ren_file";  fi
	# Working around Mac OS X case insensitive filesystem
	if [[ -d "$ren_location" && "$(dirname "$source")/" == "$temp_folder" && "$item" != "$ren_file" ]]; then mv -f "$source" "$ren_temp_location"; rm -rf "$ren_location"; source="$ren_temp_location"; fi
	# Renaming file the bsd sed way
	if [ "$item" != "$ren_file" ] && [ "$gnu_sed_available" != "yes" ]; then mv -f "$source" "$ren_location" && sed -i '' "s;^$source_ter;$ren_location_bis;g" "$log_file"
	# Renaming file the gnu sed way
	elif [ "$item" != "$ren_file" ] && [ "$gnu_sed_available" == "yes" ]; then mv -f "$source" "$ren_location" && sed -i "s;^$source_ter;$ren_location_bis;g" "$log_file"
	fi
done
fi


## Cleanup filenames
if [[ "$has_display" == "yes" && "$clean_up_filenames" == "yes" ]]; then step_number=$(( $step_number + 1 )) && echo "Step $step_number : Cleaning up filenames";  fi

# When clean_up_finenames is disabled but imdb enabled, we ll only get the last line of the log file to improve speed
if [ "$clean_up_filenames" == "yes" ]; then temp_log_file="$(echo -e "$(cat "$log_file")")"
	elif [ "$imdb_funct_on" == "yes" ]; then temp_log_file="$(echo -e "$(cat "$log_file" | sed -n '$p')")"
fi

if [ "$clean_up_filenames" == "yes" ] || [ "$imdb_funct_on" == "yes" ]; then for line in $(echo -e "$temp_log_file"); do
	file_renamed="no";
	item=`echo "$(basename "$line")"`;
	ren_file=`echo "$item"`;
	source=`echo "$line"`;
	# Resetting quality and audio quality in order not to keep values from previous pass
	if [[ "$(cat "$log_file" | egrep -i "$movies_extensions_rev")" && -d "$source" ]]; then
		movie_year="$(echo "$movie_year" | sed 's;^ ;;g')"
	else
		quality="";
		audio_quality="";
		quality_quality="";
		movie_year="";
	fi
	movie_year_bis=""
	movie_year_ter=""
	# When renaming a folder we ll use an empty extension
	# We ll get rid of the extension in the title_clean variable 
	if [ -d "$source" ]; then extension="" && title_clean=`echo "$item"`; else extension=`echo "$item" | sed 's;.*\.;.;'` && title_clean=`echo "$item" | sed 's/\(.*\)\..*/\1/'`; fi
	# I admit this line could be shortened by using OS dependent commands
	# I prefer to use a slower way that should run on all platform
	# We ll first replace dots and underscores by spaces if they are not followed by a space
	# Then we ll add a temporary underscore at the beginning and at the end
	# We ll then remove brackets
	# Then we convert everything to lowercase
	# We'll try not to fuck up capitalization in names like McLachlan or MacDonald
	# Once this is done we ll remove the underscore at the beginning of the name
	title_clean_bis=`echo "$title_clean" | sed 's/\([\._]\)\([^ ]\)/ \2/g' | sed "s/^/_/g" | sed "s/$/_/g" | sed 's/\+/ /g' | sed "s/A/a/g" | sed "s/B/b/g" | sed "s/C/c/g" | sed "s/D/d/g" | sed "s/E/e/g" | sed "s/F/f/g" | sed "s/G/g/g" | sed "s/H/h/g" | sed "s/I/i/g" | sed "s/J/j/g" | sed "s/K/k/g" | sed "s/L/l/g" | sed "s/M/m/g" | sed "s/N/n/g" | sed "s/O/o/g" | sed "s/P/p/g" | sed "s/Q/q/g" | sed "s/R/r/g" | sed "s/S/s/g" | sed "s/T/t/g" | sed "s/U/u/g" | sed "s/V/v/g" | sed "s/W/w/g" | sed "s/X/x/g" | sed "s/Y/y/g" | sed "s/Z/z/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*a/\1\2\3A/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*b/\1\2\3B/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*c/\1\2\3C/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*d/\1\2\3D/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*e/\1\2\3E/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*f/\1\2\3F/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*g/\1\2\3G/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*h/\1\2\3H/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*i/\1\2\3I/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*j/\1\2\3J/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*k/\1\2\3K/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*l/\1\2\3L/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*m/\1\2\3M/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*n/\1\2\3N/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*o/\1\2\3O/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*p/\1\2\3P/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*q/\1\2\3Q/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*r/\1\2\3R/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*s/\1\2\3S/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*t/\1\2\3T/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*u/\1\2\3U/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*v/\1\2\3V/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*w/\1\2\3W/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*x/\1\2\3X/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*y/\1\2\3Y/g" | sed "s/\([. _-]\)\(mc\)*\(mac\)*z/\1\2\3Z/g"`;
	
	# Backing up year to reuse it later
	if [[ "$(cat "$log_file" | egrep -i "$movies_extensions_rev")" && -d "$source" && "$(echo "$title_clean_bis" | grep "[. _-]\([0-9][0-9][0-9][0-9]\)[. _-]*.*$")" == "" ]]; then
		echo > /dev/null 2>&1;
	else
		movie_year=`echo "$title_clean_bis" | grep ".[. _-]\([0-9][0-9][0-9][0-9]\)[. _-]*.*$" | sed 's/[()]//g' | sed 's/\[//g' | sed 's/\]//g' | sed "s;\([^_]\)$;\1_;g" | sed "s/1080/_/g" | sed "s/..*[. _-]\([0-9][0-9][0-9][0-9]\)[. _-]*.*$/\1/g"`
	fi
	if [ "$movie_year" ]; then movie_year_bis=" ($movie_year)"; fi
	if [ "$movie_year" ]; then movie_year_ter=" %28$movie_year%29"; fi
	if [ "$movie_year" ]; then movie_year=" $movie_year"; fi
	
	# Here we ll try to guess the audio quality of the file based on patterns
	title_clean_bis="$(echo "$title_clean_bis" | sed "s;\([^_]\)$;\1_;g" | sed 's/[()]//g')"
	movies_title_clean_bis="$(echo "$title_clean_bis" | sed 's/[()]//g')"
	if [[ "$(echo "$line" | egrep -i "$movies_extensions_rev")" && $files -eq 1 ]] || [[ "$(cat "$log_file" | egrep -i "$movies_extensions_rev")" && -d "$source" ]]; then
		for aq in $(echo -e "$(echo "$audio_quality_patterns" | sed "s;,;\\\n;g")"); do
			if [ "$(echo "$movies_title_clean_bis" | egrep -i "[. _-]$aq[. _-]")" ]; then
				regexp_pat="$(echo "$aq" | sed "s/[aA]/[aA]/g" | sed "s/[bB]/[bB]/g" | sed "s/[cC]/[cC]/g" | sed "s/[dD]/[dD]/g" | sed "s/[eE]/[eE]/g" | sed "s/[fF]/[fF]/g" | sed "s/[gG]/[gG]/g" | sed "s/[hH]/[hH]/g" | sed "s/[iI]/[iI]/g" | sed "s/[jJ]/[jJ]/g" | sed "s/[kK]/[kK]/g" | sed "s/[lL]/[lL]/g" | sed "s/[mM]/[mM]/g" | sed "s/[nN]/[nN]/g" | sed "s/[oO]/[oO]/g" | sed "s/[pP]/[pP]/g" | sed "s/[qQ]/[qQ]/g" | sed "s/[rR]/[rR]/g" | sed "s/[sS]/[sS]/g" | sed "s/[tT]/[tT]/g" | sed "s/[uU]/[uU]/g" | sed "s/[vV]/[vV]/g" | sed "s/[wW]/[wW]/g" | sed "s/[xX]/[xX]/g" | sed "s/[yY]/[yY]/g" | sed "s/[zZ]/[zZ]/g")";
				audio_quality="$aq";
				movies_title_clean_bis="$(echo "$movies_title_clean_bis" | sed "s;$(echo "$movies_title_clean_bis" | egrep -o "[. _-]$regexp_pat[. _-]" | sed -n '1p').*;_;")";
			fi
		done
	else
		for aq in $(echo -e "$(echo "$audio_quality_patterns" | sed "s;,;\\\n;g")"); do
			if [ "$(echo "$title_clean_bis" | egrep -i "[. _-]$aq[. _-]")" ]; then
				regexp_pat="$(echo "$aq" | sed "s/[aA]/[aA]/g" | sed "s/[bB]/[bB]/g" | sed "s/[cC]/[cC]/g" | sed "s/[dD]/[dD]/g" | sed "s/[eE]/[eE]/g" | sed "s/[fF]/[fF]/g" | sed "s/[gG]/[gG]/g" | sed "s/[hH]/[hH]/g" | sed "s/[iI]/[iI]/g" | sed "s/[jJ]/[jJ]/g" | sed "s/[kK]/[kK]/g" | sed "s/[lL]/[lL]/g" | sed "s/[mM]/[mM]/g" | sed "s/[nN]/[nN]/g" | sed "s/[oO]/[oO]/g" | sed "s/[pP]/[pP]/g" | sed "s/[qQ]/[qQ]/g" | sed "s/[rR]/[rR]/g" | sed "s/[sS]/[sS]/g" | sed "s/[tT]/[tT]/g" | sed "s/[uU]/[uU]/g" | sed "s/[vV]/[vV]/g" | sed "s/[wW]/[wW]/g" | sed "s/[xX]/[xX]/g" | sed "s/[yY]/[yY]/g" | sed "s/[zZ]/[zZ]/g")";
				audio_quality="$aq";
				title_clean_bis="$(echo "$title_clean_bis" | sed "s;$(echo "$title_clean_bis" | egrep -o "[. _-]$regexp_pat[. _-]" | sed -n '1p');_;")";
			fi
		done
	fi
	
	# Here we ll try to guess the video quality of the file based on patterns and aggregate audio quality
	title_clean_bis="$(echo "$title_clean_bis" | sed "s;\([^_]\)$;\1_;g")"
	movies_title_clean_bis="$(echo "$movies_title_clean_bis" | sed "s;\([^_]\)$;\1_;g")"
	if [[ "$(echo "$line" | egrep -i "$movies_extensions_rev")" && $files -eq 1 ]] || [[ "$(cat "$log_file" | egrep -i "$movies_extensions_rev")" && -d "$source" ]]; then
		for q in $(echo -e "$(echo "$movies_detect_patterns,$movies_detect_patterns_pt_2" | sed "s;,;\\\n;g")"); do
			if [ "$(echo "$movies_title_clean_bis" | egrep -i "[. _-]$q[. _-]")" ]; then
				regexp_pat="$(echo "$q" | sed "s/[aA]/[aA]/g" | sed "s/[bB]/[bB]/g" | sed "s/[cC]/[cC]/g" | sed "s/[dD]/[dD]/g" | sed "s/[eE]/[eE]/g" | sed "s/[fF]/[fF]/g" | sed "s/[gG]/[gG]/g" | sed "s/[hH]/[hH]/g" | sed "s/[iI]/[iI]/g" | sed "s/[jJ]/[jJ]/g" | sed "s/[kK]/[kK]/g" | sed "s/[lL]/[lL]/g" | sed "s/[mM]/[mM]/g" | sed "s/[nN]/[nN]/g" | sed "s/[oO]/[oO]/g" | sed "s/[pP]/[pP]/g" | sed "s/[qQ]/[qQ]/g" | sed "s/[rR]/[rR]/g" | sed "s/[sS]/[sS]/g" | sed "s/[tT]/[tT]/g" | sed "s/[uU]/[uU]/g" | sed "s/[vV]/[vV]/g" | sed "s/[wW]/[wW]/g" | sed "s/[xX]/[xX]/g" | sed "s/[yY]/[yY]/g" | sed "s/[zZ]/[zZ]/g")";
				quality=" ($q)";
				quality_quality=" ($audio_quality-$q)";
				movies_title_clean_bis="$(echo "$movies_title_clean_bis" | sed "s;$(echo "$movies_title_clean_bis" | egrep -o "[. _-]$regexp_pat[. _-]" | sed -n '1p').*;_;")";
			fi
		done
	else
		for q in $(echo -e "$(echo "$movies_detect_patterns,$movies_detect_patterns_pt_2" | sed "s;,;\\\n;g")"); do
			if [ "$(echo "$title_clean_bis" | egrep -i "[. _-]$q[. _-]")" ]; then
				regexp_pat="$(echo "$q" | sed "s/[aA]/[aA]/g" | sed "s/[bB]/[bB]/g" | sed "s/[cC]/[cC]/g" | sed "s/[dD]/[dD]/g" | sed "s/[eE]/[eE]/g" | sed "s/[fF]/[fF]/g" | sed "s/[gG]/[gG]/g" | sed "s/[hH]/[hH]/g" | sed "s/[iI]/[iI]/g" | sed "s/[jJ]/[jJ]/g" | sed "s/[kK]/[kK]/g" | sed "s/[lL]/[lL]/g" | sed "s/[mM]/[mM]/g" | sed "s/[nN]/[nN]/g" | sed "s/[oO]/[oO]/g" | sed "s/[pP]/[pP]/g" | sed "s/[qQ]/[qQ]/g" | sed "s/[rR]/[rR]/g" | sed "s/[sS]/[sS]/g" | sed "s/[tT]/[tT]/g" | sed "s/[uU]/[uU]/g" | sed "s/[vV]/[vV]/g" | sed "s/[wW]/[wW]/g" | sed "s/[xX]/[xX]/g" | sed "s/[yY]/[yY]/g" | sed "s/[zZ]/[zZ]/g")";
				quality=" ($q)";
				quality_quality=" ($audio_quality-$q)";
				title_clean_bis="$(echo "$title_clean_bis" | sed "s;$(echo "$title_clean_bis" | egrep -o "[. _-]$regexp_pat[. _-]" | sed -n '1p');_;")";
			fi
		done
	fi
	
	# Remove unnecessary information in filename
	title_clean_bis="$(echo "$title_clean_bis" | sed "s;\([^_]\)$;\1_;g")"
	movies_title_clean_bis="$(echo "$movies_title_clean_bis" | sed "s;\([^_]\)$;\1_;g")"
	if [[ "$(echo "$line" | egrep -i "$movies_extensions_rev")" && $files -eq 1 ]] || [[ "$(cat "$log_file" | egrep -i "$movies_extensions_rev")" && -d "$source" ]]; then
		for i in $(echo -e "$(echo "$other_movies_patterns" | sed "s;,;\\\n;g")"); do
			if [ "$(echo "$movies_title_clean_bis" | egrep -i "[. _-]$i[. _-]")" ]; then
				regexp_pat="$(echo "$i" | sed "s/[aA]/[aA]/g" | sed "s/[bB]/[bB]/g" | sed "s/[cC]/[cC]/g" | sed "s/[dD]/[dD]/g" | sed "s/[eE]/[eE]/g" | sed "s/[fF]/[fF]/g" | sed "s/[gG]/[gG]/g" | sed "s/[hH]/[hH]/g" | sed "s/[iI]/[iI]/g" | sed "s/[jJ]/[jJ]/g" | sed "s/[kK]/[kK]/g" | sed "s/[lL]/[lL]/g" | sed "s/[mM]/[mM]/g" | sed "s/[nN]/[nN]/g" | sed "s/[oO]/[oO]/g" | sed "s/[pP]/[pP]/g" | sed "s/[qQ]/[qQ]/g" | sed "s/[rR]/[rR]/g" | sed "s/[sS]/[sS]/g" | sed "s/[tT]/[tT]/g" | sed "s/[uU]/[uU]/g" | sed "s/[vV]/[vV]/g" | sed "s/[wW]/[wW]/g" | sed "s/[xX]/[xX]/g" | sed "s/[yY]/[yY]/g" | sed "s/[zZ]/[zZ]/g")";
				movies_title_clean_bis="$(echo "$movies_title_clean_bis" | sed "s;$(echo "$movies_title_clean_bis" | egrep -o "[. _-]$regexp_pat[. _-]" | sed -n '1p').*;_;")";
			fi
		done
	else
		for i in $(echo -e "$(echo "$other_movies_patterns" | sed "s;,;\\\n;g")"); do
			if [ "$(echo "$title_clean_bis" | egrep -i "[. _-]$i[. _-]")" ]; then
				regexp_pat="$(echo "$i" | sed "s/[aA]/[aA]/g" | sed "s/[bB]/[bB]/g" | sed "s/[cC]/[cC]/g" | sed "s/[dD]/[dD]/g" | sed "s/[eE]/[eE]/g" | sed "s/[fF]/[fF]/g" | sed "s/[gG]/[gG]/g" | sed "s/[hH]/[hH]/g" | sed "s/[iI]/[iI]/g" | sed "s/[jJ]/[jJ]/g" | sed "s/[kK]/[kK]/g" | sed "s/[lL]/[lL]/g" | sed "s/[mM]/[mM]/g" | sed "s/[nN]/[nN]/g" | sed "s/[oO]/[oO]/g" | sed "s/[pP]/[pP]/g" | sed "s/[qQ]/[qQ]/g" | sed "s/[rR]/[rR]/g" | sed "s/[sS]/[sS]/g" | sed "s/[tT]/[tT]/g" | sed "s/[uU]/[uU]/g" | sed "s/[vV]/[vV]/g" | sed "s/[wW]/[wW]/g" | sed "s/[xX]/[xX]/g" | sed "s/[yY]/[yY]/g" | sed "s/[zZ]/[zZ]/g")";
				title_clean_bis="$(echo "$title_clean_bis" | sed "s;$(echo "$title_clean_bis" | egrep -o "[. _-]$regexp_pat[. _-]" | sed -n '1p');_;")";
			fi
		done
	fi

	# Remove scene names in filename
	title_clean_bis="$(echo "$title_clean_bis" | sed "s;\([^_]\)$;\1_;g" | sed "s;^\([^_]\);_\1;g")"
	movies_title_clean_bis="$(echo "$movies_title_clean_bis" | sed "s;\([^_]\)$;\1_;g" | sed "s;^\([^_]\);_\1;g")"
	if [[ "$(echo "$line" | egrep -i "$movies_extensions_rev")" && $files -eq 1 ]] || [[ "$(cat "$log_file" | egrep -i "$movies_extensions_rev")" && -d "$source" ]]; then
		for i in $(echo -e "$(echo "$scene_patterns" | sed "s;,;\\\n;g")"); do
			if [ "$(echo "$movies_title_clean_bis" | egrep -i "[. _-]$i[. _-]")" ]; then
				regexp_pat="$(echo "$i" | sed "s/[aA]/[aA]/g" | sed "s/[bB]/[bB]/g" | sed "s/[cC]/[cC]/g" | sed "s/[dD]/[dD]/g" | sed "s/[eE]/[eE]/g" | sed "s/[fF]/[fF]/g" | sed "s/[gG]/[gG]/g" | sed "s/[hH]/[hH]/g" | sed "s/[iI]/[iI]/g" | sed "s/[jJ]/[jJ]/g" | sed "s/[kK]/[kK]/g" | sed "s/[lL]/[lL]/g" | sed "s/[mM]/[mM]/g" | sed "s/[nN]/[nN]/g" | sed "s/[oO]/[oO]/g" | sed "s/[pP]/[pP]/g" | sed "s/[qQ]/[qQ]/g" | sed "s/[rR]/[rR]/g" | sed "s/[sS]/[sS]/g" | sed "s/[tT]/[tT]/g" | sed "s/[uU]/[uU]/g" | sed "s/[vV]/[vV]/g" | sed "s/[wW]/[wW]/g" | sed "s/[xX]/[xX]/g" | sed "s/[yY]/[yY]/g" | sed "s/[zZ]/[zZ]/g")"; title_clean_bis="$(echo "$title_clean_bis" | sed "s;[. _-]$regexp_pat[. _-];_;")";
				movies_title_clean_bis="$(echo "$movies_title_clean_bis" | sed "s;[. _-]$regexp_pat[. _-];_;")"
			fi
		done
		for i in $(echo -e "$(echo "$user_defined_scene_patterns_hothead_edition" | sed "s;,;\\\n;g")"); do
			echo "toto"
			if [ "$(echo "$title_clean_bis" | egrep -i "$i")" ]; then
				regexp_pat="$(echo "$i" | sed "s/[aA]/[aA]/g" | sed "s/[bB]/[bB]/g" | sed "s/[cC]/[cC]/g" | sed "s/[dD]/[dD]/g" | sed "s/[eE]/[eE]/g" | sed "s/[fF]/[fF]/g" | sed "s/[gG]/[gG]/g" | sed "s/[hH]/[hH]/g" | sed "s/[iI]/[iI]/g" | sed "s/[jJ]/[jJ]/g" | sed "s/[kK]/[kK]/g" | sed "s/[lL]/[lL]/g" | sed "s/[mM]/[mM]/g" | sed "s/[nN]/[nN]/g" | sed "s/[oO]/[oO]/g" | sed "s/[pP]/[pP]/g" | sed "s/[qQ]/[qQ]/g" | sed "s/[rR]/[rR]/g" | sed "s/[sS]/[sS]/g" | sed "s/[tT]/[tT]/g" | sed "s/[uU]/[uU]/g" | sed "s/[vV]/[vV]/g" | sed "s/[wW]/[wW]/g" | sed "s/[xX]/[xX]/g" | sed "s/[yY]/[yY]/g" | sed "s/[zZ]/[zZ]/g")"; title_clean_bis="$(echo "$title_clean_bis" | sed "s;$regexp_pat.*;_;")";
				movies_title_clean_bis="$(echo "$movies_title_clean_bis" | sed "s;$regexp_pat.*;_;")"
			fi
		done
	else
		for i in $(echo -e "$(echo "$scene_patterns" | sed "s;,;\\\n;g")"); do
			if [ "$(echo "$title_clean_bis" | egrep -i "[. _-]$i[. _-]")" ]; then
				regexp_pat="$(echo "$i" | sed "s/[aA]/[aA]/g" | sed "s/[bB]/[bB]/g" | sed "s/[cC]/[cC]/g" | sed "s/[dD]/[dD]/g" | sed "s/[eE]/[eE]/g" | sed "s/[fF]/[fF]/g" | sed "s/[gG]/[gG]/g" | sed "s/[hH]/[hH]/g" | sed "s/[iI]/[iI]/g" | sed "s/[jJ]/[jJ]/g" | sed "s/[kK]/[kK]/g" | sed "s/[lL]/[lL]/g" | sed "s/[mM]/[mM]/g" | sed "s/[nN]/[nN]/g" | sed "s/[oO]/[oO]/g" | sed "s/[pP]/[pP]/g" | sed "s/[qQ]/[qQ]/g" | sed "s/[rR]/[rR]/g" | sed "s/[sS]/[sS]/g" | sed "s/[tT]/[tT]/g" | sed "s/[uU]/[uU]/g" | sed "s/[vV]/[vV]/g" | sed "s/[wW]/[wW]/g" | sed "s/[xX]/[xX]/g" | sed "s/[yY]/[yY]/g" | sed "s/[zZ]/[zZ]/g")"; title_clean_bis="$(echo "$title_clean_bis" | sed "s;[. _-]$regexp_pat[. _-];_;")";
			fi
		done
		for i in $(echo -e "$(echo "$user_defined_scene_patterns_hothead_edition" | sed "s;,;\\\n;g")"); do
			echo "toto"
			if [ "$(echo "$title_clean_bis" | egrep -i "$i")" ]; then
				regexp_pat="$(echo "$i" | sed "s/[aA]/[aA]/g" | sed "s/[bB]/[bB]/g" | sed "s/[cC]/[cC]/g" | sed "s/[dD]/[dD]/g" | sed "s/[eE]/[eE]/g" | sed "s/[fF]/[fF]/g" | sed "s/[gG]/[gG]/g" | sed "s/[hH]/[hH]/g" | sed "s/[iI]/[iI]/g" | sed "s/[jJ]/[jJ]/g" | sed "s/[kK]/[kK]/g" | sed "s/[lL]/[lL]/g" | sed "s/[mM]/[mM]/g" | sed "s/[nN]/[nN]/g" | sed "s/[oO]/[oO]/g" | sed "s/[pP]/[pP]/g" | sed "s/[qQ]/[qQ]/g" | sed "s/[rR]/[rR]/g" | sed "s/[sS]/[sS]/g" | sed "s/[tT]/[tT]/g" | sed "s/[uU]/[uU]/g" | sed "s/[vV]/[vV]/g" | sed "s/[wW]/[wW]/g" | sed "s/[xX]/[xX]/g" | sed "s/[yY]/[yY]/g" | sed "s/[zZ]/[zZ]/g")"; title_clean_bis="$(echo "$title_clean_bis" | sed "s;$regexp_pat.*;_;")";
			fi
		done
	fi
	
	# Doing some more cleanup
	title_clean_bis=`echo "$title_clean_bis" | sed 's/[()]//g' | sed 's/\[//g' | sed 's/\]//g' | sed "s/^[. _-]*//g" | sed "s/[. _-]*$//g" | sed "s/_/ /g"`;
	if [[ "$(echo "$line" | egrep -i "$movies_extensions_rev")" && $files -eq 1 ]] || [[ "$(cat "$log_file" | egrep -i "$movies_extensions_rev")" && -d "$source" ]]; then
		series_title_clean_bis=`echo "$movies_title_clean_bis" | sed 's/[()]//g' | sed 's/\[//g' | sed 's/\]//g' | sed "s/^[. _-]*//g" | sed "s/[. _-]*$//g" | sed "s/_/ /g"`;
	else
		series_title_clean_bis=`echo "$title_clean_bis" | sed 's/[()]//g' | sed 's/\[//g' | sed 's/\]//g' | sed "s/^[. _-]*//g" | sed "s/[. _-]*$//g" | sed "s/_/ /g"`;
	fi
	movies_title_clean_bis=`echo "$movies_title_clean_bis" | sed 's/\(.\)[. _-][0-9][0-9][0-9][0-9][. _-].*/\1/g' | sed 's/[()]//g' | sed 's/\[//g' | sed 's/\]//g' | sed "s/^[. _-]*//g" | sed "s/[. _-]*$//g" | sed "s/_/ /g"`;

	# Remove underscores at the beginning and at the end of the filename
	title_clean_ter=`echo "$title_clean_bis" | sed "s/^[. _-]*//g" | sed "s/[. _-]*$//g"`;
	series_title_clean_ter=`echo "$series_title_clean_bis" | sed "s/^[. _-]*//g" | sed "s/[. _-]*$//g"`;
	movies_title_clean_ter=`echo "$movies_title_clean_bis" | sed 's/[()]//g' | sed 's/\[//g' | sed 's/\]//g' | sed "s/^[. _-]*//g" | sed "s/[. _-]*$//g" | sed "s/_/ /g"`;
	if [[ "$repack_handling" == "yes" && "$(echo "$item" | egrep -i "([. _])repack([. _])|([. _])proper([. _])|([. _])rerip([. _])|([. _])real([. _])")" ]]; then is_repack=" REPACK"; else is_repack=""; fi

	# Focusing on TV Series with a SXXEXX pattern
	if [[ "$(echo "$item" | egrep -i "([sS])([0-9])([0-9])([eE])([0-9])([0-9])")" ]] && [[ ! "$(echo "$line" | egrep -i "\.iso$|\.img$")" || ! "$(cat "$log_file" | egrep -i "\.dvd$")" ]] && [[ -d "$source" || "$(echo "$line" | egrep -i "$tv_show_extensions_rev")" ]]; then
		# For TV series we ll only display quality with 720p and 1080p files
		if [[ "$quality" != " (720p)" && "$quality" != " (1080p)" ]] || [[ "$movies_rename_schema" == "type_1" ]]; then quality=""; fi
		series_title=`echo "$series_title_clean_ter" | sed 's;.\([sS]\)\([0-9]\)\([0-9]\)\([eE]\)\([0-9]\)\([0-9]\).*;;'`;
		series_episode=`echo "$item" | sed 's;.*\([sS]\)\([0-9]\)\([0-9]\)\([eE]\)\([0-9]\)\([0-9]\).*;S\2\3E\5\6;g'`;
		# The file will then be renamed "Title SXXEXX.ext", "Title SXXEXX (720p).ext" or "Title SXXEXX (1080p).ext"
		ren_file=`echo "$series_title $series_episode$is_repack$quality$extension"`;
		file_renamed="yes";
	# Focusing on TV Shows with a YYYY.MM.DD pattern
	elif [[ "$(echo "$item" | egrep -i "([0-9])([0-9])([0-9])([0-9]).([0-9])([0-9]).([0-9])([0-9])")" ]] && [[ ! "$(echo "$line" | egrep -i "\.iso$|\.img$")" || ! "$(cat "$log_file" | egrep -i "\.dvd$")" ]] && [[ -d "$source" || "$(echo "$line" | egrep -i "$tv_show_extensions_rev")" ]]; then
		# For TV series we ll only display quality with 720p and 1080p files
		if [[ "$quality" != " (720p)" && "$quality" != " (1080p)" ]] || [[ "$movies_rename_schema" == "type_1" ]]; then quality=""; fi
		talk_show_title=`echo "$series_title_clean_ter" | sed 's/\([0-9]\)\([0-9]\)\([0-9]\)\([0-9]\).\([0-9]\)\([0-9]\).\([0-9]\)\([0-9]\)/\1\2\3\4-\5\6-\7\8/g'`;
		# The file will then be renamed "Title YYYY-MM-DD.ext"
		ren_file=`echo "$talk_show_title$is_repack$quality$extension"`;
		file_renamed="yes";
	# Focusing on movies. Type_1 renaming will look like "Title (YYYY).ext"
	elif [[ "$movies_rename_schema" == "type_1" ]] && [[ ! "$(echo "$line" | egrep -i "\.iso$|\.img$")" || ! "$(cat "$log_file" | egrep -i "\.dvd$")" ]] && [[ "$(echo "$line" | egrep -i "$movies_extensions_rev")" && $files -eq 1 ]]; then
		ren_file=`echo "$movies_title_clean_ter$movie_year_bis$extension"`;
		# Storing movie title in an imdb friendly format
		imdb_title=`echo "$(basename "$movies_title_clean_ter")$movie_year_ter" | sed "s/^[. _-]*//g" | sed "s/[. _-]*$//g" | sed "s; [aA][nN][dD] ; ;g" | sed "s; ;+;g"`;
		file_renamed="yes";
	# Focusing on movies in directories. Type_1 renaming will look like "Title (YYYY).ext"
	elif [[ "$movies_rename_schema" == "type_1" ]] && [[ ! "$(echo "$line" | egrep -i "\.iso$|\.img$")" || ! "$(cat "$log_file" | egrep -i "\.dvd$")" ]] && [[ "$(cat "$log_file" | egrep -i "$movies_extensions_rev")" && -d "$source" ]]; then
		ren_file=`echo "$movies_title_clean_ter$movie_year_bis$extension"`;
		# Storing movie title in an imdb friendly format
		imdb_title=`echo "$(basename "$movies_title_clean_ter")$movie_year_ter" | sed "s/^[. _-]*//g" | sed "s/[. _-]*$//g" | sed "s; [aA][nN][dD] ; ;g" | sed "s; ;+;g"`;
		file_renamed="yes";
	# Focusing on movies. Type_2 renaming will look like "Title YYYY (Video_Quality).ext"
	elif [[ "$movies_rename_schema" == "type_2" ]] && [[ ! "$(echo "$line" | egrep -i "\.iso$|\.img$")" || ! "$(cat "$log_file" | egrep -i "\.dvd$")" ]] && [[ "$(echo "$line" | egrep -i "$movies_extensions_rev")" && $files -eq 1 ]]; then
		ren_file=`echo "$movies_title_clean_ter$movie_year$quality$extension"`;
		# Storing movie title in an imdb friendly format
		imdb_title=`echo "$(basename "$movies_title_clean_ter")$movie_year_ter" | sed "s/^[. _-]*//g" | sed "s/[. _-]*$//g" | sed "s; [aA][nN][dD] ; ;g" | sed "s; ;+;g"`;
		file_renamed="yes";
	# Focusing on movies in directories. Type_2 renaming will look like "Title YYYY (Video_Quality).ext"
	elif [[ "$movies_rename_schema" == "type_2" ]] && [[ ! "$(echo "$line" | egrep -i "\.iso$|\.img$")" || ! "$(cat "$log_file" | egrep -i "\.dvd$")" ]] && [[ "$(cat "$log_file" | egrep -i "$movies_extensions_rev")" && -d "$source" ]]; then
		ren_file=`echo "$movies_title_clean_ter$movie_year$quality$extension"`;
		# Storing movie title in an imdb friendly format
		imdb_title=`echo "$(basename "$movies_title_clean_ter")$movie_year_ter" | sed "s/^[. _-]*//g" | sed "s/[. _-]*$//g" | sed "s; [aA][nN][dD] ; ;g" | sed "s; ;+;g"`;
		file_renamed="yes";
	# Focusing on movies. Type_3 renaming will look like "Title YYYY (Audio_Quality-Video_Quality).ext"
	elif [[ "$movies_rename_schema" == "type_3" ]] && [[ ! "$(echo "$line" | egrep -i "\.iso$|\.img$")" || ! "$(cat "$log_file" | egrep -i "\.dvd$")" ]] && [[ "$(echo "$line" | egrep -i "$movies_extensions_rev")" && $files -eq 1 ]]; then
		ren_file=`echo "$movies_title_clean_ter$quality_quality$extension"`;
		# Storing movie title in an imdb friendly format
		imdb_title=`echo "$(basename "$movies_title_clean_ter")$movie_year_ter" | sed "s/^[. _-]*//g" | sed "s/[. _-]*$//g" | sed "s; [aA][nN][dD] ; ;g" | sed "s; ;+;g"`;
		file_renamed="yes";
	# Focusing on movies in directories. Type_3 renaming will look like "Title YYYY (Audio_Quality-Video_Quality).ext"
	elif [[ "$movies_rename_schema" == "type_3" ]] && [[ ! "$(echo "$line" | egrep -i "\.iso$|\.img$")" || ! "$(cat "$log_file" | egrep -i "\.dvd$")" ]] && [[ "$(cat "$log_file" | egrep -i "$movies_extensions_rev")" && -d "$source" ]]; then
		ren_file=`echo "$movies_title_clean_ter$quality_quality$extension"`;
		# Storing movie title in an imdb friendly format
		imdb_title=`echo "$(basename "$movies_title_clean_ter")$movie_year_ter" | sed "s/^[. _-]*//g" | sed "s/[. _-]*$//g" | sed "s; [aA][nN][dD] ; ;g" | sed "s; ;+;g"`;
		file_renamed="yes";
	fi
	# Now we ll apply the renaming
	if [[ "$file_renamed" != "yes" && "$item" != "$title_clean_ter" ]] && [[ ! "$(echo "$line" | egrep -i "\.iso$|\.img$")" || ! "$(cat "$log_file" | egrep -i "\.dvd$")" ]] && [[ -d "$source" || "$(echo "$line" | egrep -i "$supported_extensions_rev")" ]]; then ren_file="$title_clean_ter$extension"; fi
	bis="_bis"
	ren_location=`echo "$(dirname "$source")/$ren_file"`;
	ren_temp_location=`echo "$(dirname "$source")/$ren_file$bis"`;
	source_bis=`echo "$line"`;
	source_ter=$(echo "$line" | sed "s;\([][]\);\\\\\1;g") && source_ter=`echo "$source_ter"`;
	# Removing brackets
	ren_location_bis=$(echo "$ren_location" | sed "s;\([][)(]\);\\\\\1;g") && ren_location_bis=`echo "$ren_location_bis"`;
	if [ "$clean_up_filenames" == "yes" ] && [ "$has_display" == "yes" ] && [ "$item" != "$ren_file" ]; then echo "- Renaming $item to $ren_file";  fi
	# Working around Mac OS X case insensitive filesystem
	if [ "$clean_up_filenames" == "yes" ] && [[ -d "$ren_location" && "$(dirname "$source")/" == "$temp_folder" && "$item" != "$ren_file" ]]; then mv -f "$source" "$ren_temp_location"; rm -rf "$ren_location"; source="$ren_temp_location"; fi
	# Renaming file the bsd sed way
	if [ "$clean_up_filenames" == "yes" ] && [ "$item" != "$ren_file" ] && [ "$gnu_sed_available" != "yes" ]; then mv -f "$source" "$ren_location" && sed -i '' "s;^$source_ter;$ren_location_bis;g" "$log_file"
	# Renaming file the gnu sed way
	elif [ "$clean_up_filenames" == "yes" ] && [ "$item" != "$ren_file" ] && [ "$gnu_sed_available" == "yes" ]; then mv -f "$source" "$ren_location" && sed -i "s;^$source_ter;$ren_location_bis;g" "$log_file"
	fi
done
fi


# Resetting folder_short value the bsd sed way
if [[ "$folder_short" && "$tv_shows_fix_numbering" == "yes" && "$gnu_sed_available" != "yes" ]] || [[ "$folder_short" && "$clean_up_filenames" == "yes" && "$gnu_sed_available" != "yes" ]] || [[ "$folder_short" && "$imdb_funct_on" == "yes" && "$gnu_sed_available" != "yes" ]]; then folder_short=`echo "$(cat "$log_file" | sed -n '$p' | sed 's;.*/;;g')"`; sed -i '' '$d' "$log_file"
# Resetting folder_short value the gnu sed way
elif [[ "$folder_short" && "$tv_shows_fix_numbering" == "yes" && "$gnu_sed_available" == "yes" ]] || [[ "$folder_short" && "$clean_up_filenames" == "yes" && "$gnu_sed_available" == "yes" ]] || [[ "$folder_short" && "$imdb_funct_on" == "yes" && "$gnu_sed_available" != "yes" ]]; then folder_short=`echo "$(cat "$log_file" | sed -n '$p' | sed 's;.*/;;g')"`; sed -i '$d' "$log_file"
fi
# Generating a surrounding folder for movies if force_single_file_movies_folder is turned on
if [[ "$force_single_file_movies_folder" == "yes" && ! "$folder_short" ]]; then
	source_file=`echo "$(cat "$log_file")"`
	if [[ "$(echo "$source_file" | egrep -i "$movies_extensions_rev")" ]] && [[ "$(echo "$quality" | egrep -i "$movies_detect_patterns_rev" )" || "$(echo "$quality" | egrep -i "$movies_detect_patterns_pt_2_rev" )" ]] && [[ "$(echo "$source_file" | egrep -v "[sS][0-9][0-9][eE][0-9][0-9]")" && "$(echo "$source_file" | egrep -v "[0-9][0-9][0-9][0-9].[0-9][0-9].[0-9][0-9]")" ]]; then
		folder_short=`echo "$source_file" | sed 's/\(.*\)\..*/\1/' | sed 's;.*/;;g'`
		new_destination=`echo "$temp_folder$folder_short/"`
		mkdir -p "$new_destination"
		mv -f "$source_file" "$new_destination"
		echo "$(find "$temp_folder$folder_short" -maxdepth 1 -mindepth 1 -type f | egrep -i "$supported_extensions_rev")" > "$log_file"
	fi
fi


## IMDB routine. This will generate NFO, Poster and fanart files
if [ "$imdb_title" ] && [ "$imdb_funct_on" == "yes" ] && [ "$subtitles_mode" != "yes" ]; then
	if [ "$has_display" == "yes" ]; then step_number=$(( $step_number + 1 )) && echo "Step $step_number : Generating NFO and downloading Poster"; fi
	
	# Starting debug log for imdb features
	if [[ "$debug_mode" == "yes" ]] && [ "$imdb_funct_on" == "yes" ]; then 
		if [ ! -f "$debug_log" ]; then touch "$debug_log"; fi
		echo "--> LOG START <--" >> "$debug_log";
		echo "Started on $(date)" >> "$debug_log";
		# Adding imdb title to the debug log
		echo "IMDB Title: $imdb_title" >> "$debug_log";
		# Adding imdb poster format to the debug log
		if [[ "$debug_mode" == "yes" ]] && [[ "$imdb_poster" == "yes" ]]; then echo "IMDB Poster format: $imdb_poster_format" >> "$debug_log"; fi
		# Adding fanart format to the debug log
		if [[ "$debug_mode" == "yes" ]] && [[ "$imdb_fanart" == "yes" ]]; then echo "Fanart Poster format: $imdb_fanart_format" >> "$debug_log"; fi
	fi
	
	# Defining the poster format value to fetch in the imdWebService XML
	if [ "$imdb_poster_format" == "normal" ]; then poster_size="POSTER"
	elif [ "$imdb_poster_format" == "small" ]; then poster_size="POSTER_SMALL"
	elif [ "$imdb_poster_format" == "large" ]; then poster_size="POSTER_LARGE"
	elif [ "$imdb_poster_format" == "full" ]; then poster_size="POSTER_FULL"
	fi
	
	# Downloading imdbWebService XML and storing it in a variable
	if [[ "$wget_curl" == *wget* ]]; then
		# Using wget to fetch data if available
		xml_cont=`echo "$("$wget_curl" -q "http://protoss.no-ip.org/imdbWebService.php?m=$imdb_title&o=xml" -O -; wait)"`;
	elif [[ "$wget_curl" == *curl* ]]; then
		# Using curl to fetch data if available
		xml_cont=`echo "$("$wget_curl" -silent -i "http://protoss.no-ip.org/imdbWebService.php?m=$imdb_title&o=xml"; wait)"`;
	fi
	
	# Adding XML path to the debug log
	if [[ "$debug_mode" == "yes" ]]; then echo "IMDB XML URL: http://protoss.no-ip.org/imdbWebService.php?m=$imdb_title&o=xml" >> "$debug_log"; fi
	if [ "$xml_cont" ]; then
		# Getting IMDB URL from the XML file
		imdb_url=`echo "$(echo "$xml_cont" | grep "<IMDB_URL>" | sed 's/^[ \t]*//' | sed 's/[ \t]*$//' | sed 's/<[^>]*>//g')"`;
		# Adding IMDB URL to the debug log
		if [[ "$debug_mode" == "yes" ]]; then echo "IMDB URL: $imdb_url" >> "$debug_log"; fi
		# Getting IMDB ID from the XML file
		imdb_id=`echo "$(echo "$xml_cont" | grep "<TITLE_ID>" | sed 's/^[ \t]*//' | sed 's/[ \t]*$//' | sed 's/<[^>]*>//g')"`;
		# Adding IMDB ID to the debug log
		if [[ "$debug_mode" == "yes" ]]; then echo "IMDB ID: $imdb_id" >> "$debug_log"; fi
		# Getting IMDB Poster URL from the XML file
		poster_url=`echo "$(echo "$xml_cont" | grep "<$poster_size>" | sed 's/^[ \t]*//' | sed 's/[ \t]*$//' | sed 's/<[^>]*>//g')"`;
		# Adding IMDB Poster URL to the debug log
		if [[ "$debug_mode" == "yes" ]]; then echo "IMDB POSTER URL: $poster_url" >> "$debug_log"; fi
		# If IMDB Poster URL is available, downloading it
		if [[ "$wget_curl" == *wget* ]] && [[ "$imdb_poster" == "yes" && "$poster_url" ]]; then
			# Using wget to fetch data if available
			"$wget_curl" -q "$poster_url" -O "$temp_folder_without_slash/temp_poster"; wait;
		elif [[ "$wget_curl" == *curl* ]] && [[ "$imdb_poster" == "yes" && "$poster_url" ]]; then
			# Using curl to fetch data if available
			"$wget_curl" -# -C - -o "$temp_folder_without_slash/temp_poster" "$poster_url" > /dev/null 2>&1; wait;
		fi		
		# Indicate IMDB Poster as downloaded to the debug log
		if [[ "$debug_mode" == "yes" && -f "$temp_folder_without_slash/temp_poster" ]]; then echo "IMDB Poster downloaded" >> "$debug_log"; fi
		# Getting Fanart if the imdb_id is available
		if [[ "$imdb_fanart" == "yes" && "$imdb_id" ]]; then
			# Downloading TheMovieDataBase XML and storing it in a variable
			if [[ "$wget_curl" == *wget* ]]; then
				# Using wget to fetch data if available
				themoviedb_xml_cont=`echo "$("$wget_curl" -q "http://api.themoviedb.org/2.1/Movie.imdbLookup/en/xml/57983e31fb435df4df77afb854740ea9/$imdb_id" -O -; wait)"`;
			elif [[ "$wget_curl" == *curl* ]]; then
				# Using curl to fetch data if available
				themoviedb_xml_cont=`echo "$("$wget_curl" -silent -i "http://api.themoviedb.org/2.1/Movie.imdbLookup/en/xml/57983e31fb435df4df77afb854740ea9/$imdb_id"; wait)"`;
			fi			
			# Adding XML path to the debug log
			if [[ "$debug_mode" == "yes" ]]; then echo "TMDB XML URL: http://api.themoviedb.org/2.1/Movie.imdbLookup/en/xml/57983e31fb435df4df77afb854740ea9/$imdb_id" >> "$debug_log"; fi
			# Getting Fanart URL from the XML file
			fanart_url=`echo "$(echo "$themoviedb_xml_cont" | grep "backdrop" | grep "size=\"$imdb_fanart_format\"" | sed q | sed 's;.*url="\(.*\.jpg\).*;\1;g')"`;
			# Adding Fanart URL to the debug log
			if [[ "$debug_mode" == "yes" ]]; then echo "TMDB fanart url: $fanart_url" >> "$debug_log"; fi
			# If Fanart URL is available, downloading it
			if [[ "$wget_curl" == *wget* ]] && [[ "$imdb_fanart" == "yes" && "$fanart_url" ]]; then
				# Using wget to fetch data if available
				"$wget_curl" -q "$fanart_url" -O "$temp_folder_without_slash/temp_fanart"; wait;
			elif [[ "$wget_curl" == *curl* ]] && [[ "$imdb_fanart" == "yes" && "$fanart_url" ]]; then
				# Using curl to fetch data if available
				"$wget_curl" -# -C - -o "$temp_folder_without_slash/temp_fanart" "$fanart_url" > /dev/null 2>&1; wait;
			fi
			# Indicate Fanart as downloaded to the debug log
			if [[ "$debug_mode" == "yes" && -f "$temp_folder_without_slash/temp_fanart" ]]; then echo "Fanart downloaded" >> "$debug_log"; fi
		fi
	fi

	
	## If the torrent only contains one file and imdb features are activated, we ll create a surrounding folder
	if [ ! "$folder_short" ] && [ "$xml_cont" ]; then
		folder_short=`echo "$(basename "$(cat "$log_file")")" | sed 's/\(.*\)\..*/\1/' | sed 's;.*/;;g'`;
		mkdir -p "$temp_folder$folder_short/";
		mv -f "$(cat "$log_file")" "$temp_folder$folder_short/"
	fi
	
	## We ll now generate nfo, poster and fanart. We ll also duplicate them for every movie file
	if [ "$imdb_url" ]; then
		for item in $(find "$temp_folder$folder_short" -type f | egrep -i "$(echo "\.$(echo "$movies_extensions" | sed "s;,srt;;" | sed "s;,idx;;" | sed "s;,sub;;" | sed 's;,;\$\|\\\.;g')$")"); do
			nfo_file=`echo "$item" | sed 's/\(.*\)\..*/\1.nfo/'`;
			poster=`echo "$item" | sed 's/\(.*\)\..*/\1.jpg/'`;
			fanart=`echo "$item" | sed 's/\(.*\)\..*/\1.fanart.jpg/'`;
			# Generating NFO with the IMDB URL
			if [ "$imdb_url" ] && [ "$imdb_nfo" == "yes" ]; then echo "$imdb_url" > "$nfo_file"; fi
			# Indicating in the debug log that NFO has been generated
			if [[ "$debug_mode" == "yes" && -f "$nfo_file" ]]; then echo "NFO generated: $nfo_file" >> "$debug_log"; fi
			# Generating IMDB Poster
			if [ -f "$temp_folder_without_slash/temp_poster" ] && [ "$imdb_poster" == "yes" ]; then cp -f "$temp_folder_without_slash/temp_poster" "$poster"; fi
			# Indicating in the debug log that Poster has been saved
			if [[ "$debug_mode" == "yes" && -f "$temp_folder_without_slash/temp_poster" ]]; then echo "IMDB Poster generated: $poster" >> "$debug_log"; fi
			# Generating Fanart
			if [ -f "$temp_folder_without_slash/temp_fanart" ] && [ "$imdb_fanart" == "yes" ]; then cp -f "$temp_folder_without_slash/temp_fanart" "$fanart"; fi
			# Indicating in the debug log that Fanart has been saved
			if [[ "$debug_mode" == "yes" && -f "$temp_folder_without_slash/temp_fanart" ]]; then echo "Fanart Poster downloaded: $fanart" >> "$debug_log"; fi
		done
	elif [ "$disable_nmj_scan" == "yes" ]; then
		if [[ "$debug_mode" == "yes" ]]; then echo "Sorry, I could not find that title on IMDB" >> "$debug_log"; fi
		touch "$temp_folder$folder_short/.no_all.nmj";
	fi
	
	
	# Removing remp poster and temp fanart
	if [ -f "$temp_folder_without_slash/temp_poster" ]; then rm "$temp_folder_without_slash/temp_poster"; fi
	if [ -f "$temp_folder_without_slash/temp_fanart" ]; then rm "$temp_folder_without_slash/temp_fanart"; fi
	# Adding jpg, nfo and nmj to the list of supported extensions
	supported_extensions_rev="$supported_extensions_rev|\.nfo$|\.jpg$|\.nmj$"
	movies_extensions_rev="$movies_extensions_rev|\.nfo$|\.jpg$|\.nmj$"
	# End debug log
	if [[ "$debug_mode" == "yes" ]]; then
		echo "Ended on $(date)" >> "$debug_log";
		echo "--> LOG END <--" >> "$debug_log";
	fi
	# Generating a brand new log_files with all the new imdb files
	if [ "$folder_short" ]; then echo "$(find "$temp_folder$folder_short" -maxdepth 1 -mindepth 1 -type f | egrep -i "$supported_extensions_rev")" > "$log_file"; fi
fi


## Convert DTS track from MKV files to AC3, img disc images to iso disc images and creates a folder and a cuesheet for Wii backups
if [ "$has_display" == "yes" ] && [[ "$dts_post" == "yes" || "$img_post" == "yes" || "$wii_post" == "yes" ]] && [ "$subtitles_mode" != "yes" ] && [ "$(cat "$log_file" | egrep -i "\.mkv$|\.img$|([. _-])wii([. _-])")" ]; then step_number=$(( $step_number + 1 )) && echo "Step $step_number : Converting DTS track to AC3, IMG to ISO and Creating Wii Cuesheet";  fi
for line in $(cat "$log_file"); do
	source_trimmed=`echo "$line" | sed 's/\(.*\)\..*/\1/' | sed 's;.*/;;g'`
	source_file=`echo "$line"`
	source_filename=`echo "$(basename "$line")"`
	source_dir=`echo "$(dirname "$line")"`
	# Converting DTS track, converting it to AC3 and adding this track to the file
	if [ "$(echo "$line" | egrep -i "\.mkv$" )" ] && [ "$dts_post" == "yes" ]; then
		if [ "$has_display" == "yes" ]; then echo "- Converting $source_filename from DTS to AC3";  fi
		if [ "$has_display" == "yes" ]; then "$mkvdts2ac3_bin" -w "$temp_folder" -k "$source_file"; else "$mkvdts2ac3_bin" -w "$temp_folder" -k "$source_file" > /dev/null 2>&1; fi
	# Converting .img disk images to .iso. If this doesn t work rename .img to .iso
	elif [ "$(echo "$line" | egrep -i "\.img$" )" ] && [ "$img_post" == "yes" ]; then
		iso=`echo "$source_dir/$source_trimmed.iso"`
		if [ "$has_display" == "yes" ]; then echo "- Converting $source_filename to an ISO";  fi
		if [ "$has_display" == "yes" ]; then "$ccd2iso_bin" "$source_file" "$iso"; else "$ccd2iso_bin" "$source_file" "$iso" > /dev/null 2>&1; fi
		iso_size="$(stat -c %s "$iso")"
		# Detecting size of resulting file. If too small it means it failed and is already an .iso
		if [ "$iso_size" -lt 1000 ]; then
			if [ "$has_display" == "yes" ]; then echo "Actually $source_filename is probably already an ISO";  fi
			rm -f "$iso" && mv -f "$source_file" "$iso"
		else rm "$source_file"
		fi
		# Rewriting log_file
		if [ "$gnu_sed_available" != "yes" ]; then sed -i '' "s;$source_file;$iso;g" "$log_file"; else sed -i "s;$source_file;$iso;g" "$log_file"; fi
	# Generating a CloneCD Cuesheet for Wii backups
	elif [ "$(echo "$line" | egrep -i "([. _-])wii([. _-])" )" ] && [ "$(echo "$line" | egrep -i "\.iso$" )" ] && [ "$wii_post" == "yes" ]; then
		source_trimmed=`echo "$line" | sed 's/\(.*\)\..*/\1/' | sed 's;.*/;;g'`
		new_folder=`echo "$temp_folder$source_trimmed/"`
		dvd_file=`echo "$new_folder$source_trimmed.dvd"`
		# Creating a surrounding folder and making changes to the log_file the bsd sed way
		if [ ! "$folder_short" ] && [ "$gnu_sed_available" != "yes" ]; then
			mkdir -p "$new_folder" && folder_short="$source_trimmed" && mv -f "$source_file" "$new_folder" && sed -i '' "s;$source_file;$new_folder$source_filename;g" "$log_file"
		# Creating a surrounding folder and making changes to the log_file the bsd sed way
		elif [ ! "$folder_short" ] && [ "$gnu_sed_available" == "yes" ]; then
			mkdir -p "$new_folder" && folder_short="$source_trimmed" && mv -f "$source_file" "$new_folder" && sed -i "s;$source_file;$new_folder$source_filename;g" "$log_file"
		fi
		if [ "$has_display" == "yes" ]; then echo "- Creating a Cuesheet for $source_filename";  fi
		# Writing the Cuesheet
		echo "$source_filename" > "$dvd_file"
		# Rewriting log_file
		echo "$dvd_file" >> "$log_file"
	fi
done


## Copy or move TV Shows, movies and music to a specific folder
if [ "$has_display" == "yes" ] && [ "$subtitles_mode" != "yes" ] && [[ "$tv_shows_post" != "no" || "$music_post" != "no" || "$movies_post" != "no" ]]; then step_number=$(( $step_number + 1 )) && echo "Step $step_number : Taking care of TV Shows, Music and Movie files";  fi

# If in GUI mode, we turn tv_shows_post, music_post and movies_post from move to copy mode, unless the user says otherwise
user_confirm_move=0
if [ "$has_display" == "yes" ] && [[ "$tv_shows_post" == "move" || "$music_post" == "move" || "$movies_post" == "move" ]] && [[ "$alt_dest_enabled" == "yes" ]]; then
	while [[ "$user_confirm_move" != "1" ]] && [[ "$user_confirm_move" != "2" ]]; do
		echo -e "\n\nOops, are you sure you want to move your files and not simply copy them ?\nYour processed torrent may not show up in your destination folder\n\n1) Yes, I'm sure\n2) You may be right, I'd rather copy them\n\n"
		read user_confirm_move
		if [[ "$user_confirm_move" != "1" ]] && [[ "$user_confirm_move" != "2" ]]; then
			echo -e "\n\nUh-oh, I cannot understand your answer, please try again"
		elif [[ "$user_confirm_move" == "1" ]] || [[ "$user_confirm_move" == "2" ]]; then
			echo -e "\n\nDuly noted\n\n"
		fi
	done
	if [ "$tv_shows_post" != "no" ] && [[ "$user_confirm_move" == "2" ]]; then
		tv_shows_post="copy";
	fi
	if [ "$music_post" != "no" ] && [[ "$user_confirm_move" == "2" ]]; then
		music_post="copy";
	fi
	if [ "$movies_post" != "no" ] && [[ "$user_confirm_move" == "2" ]]; then
		movies_post="copy";
	fi
fi

additional_permissions="additional_permissions"
touch "$temp_folder$additional_permissions"

if [[ "$tv_shows_post" != "no" || "$music_post" != "no" || "$movies_post" != "no" ]]; then
for line in $(cat "$log_file"); do
	source_file=`echo "$line"`
	source_filename=`echo "$(basename "$line")"`
	
	# Getting default values for post
	if [ "$(echo "$line" | egrep -i "$music_extensions_rev" )" ] && [ "$music_post" != "no" ]; then
		new_destination=`echo "$music_post_path"`
	elif [[ "$(echo "$quality" | egrep -i "$movies_detect_patterns_rev" )" || "$(echo "$quality" | egrep -i "$movies_detect_patterns_pt_2_rev" )" ]] && [ "$(echo "$line" | egrep -i "$movies_extensions_rev" )" ] && [ "$movies_post" != "no" ];
		then new_destination=`echo "$movies_post_path"`
	else new_destination=`echo "$movies_post_path"`
	fi
	
	# Guessing path for /Series/Episode (s) or /Series/Season X/Episode (ss)
	# or /Series/Season XX/Episode (sss) ordering
	if [ "$(echo "$source_filename" | egrep -i "([. _])s([0])([0-9])e([0-9])([0-9])([. _])")" ]; then
		series_season_v1=`echo "$source_filename" | sed 's;\(.*\).\([sS]\)\([0-9]\)\([0-9]\)\([eE]\)\([0-9]\)\([0-9]\).*;Season \4;g'`;
		series_season_v2=`echo "$source_filename" | sed 's;\(.*\).\([sS]\)\([0-9]\)\([0-9]\)\([eE]\)\([0-9]\)\([0-9]\).*;Season \3\4;g'`;
		series_title=`echo "$source_filename" | sed 's;\(.*\).\([sS]\)\([0-9]\)\([0-9]\)\([eE]\)\([0-9]\)\([0-9]\).*;\1/;' | sed 's;\(.*\).\([0-9]\)\([0-9]\)\([0-9]\)\([0-9]\).\([0-9]\)\([0-9]\).\([0-9]\)\([0-9]\).*;\1/;'`;
	elif [ "$(echo "$source_filename" | egrep -i "([. _])s([1-9])([0-9])e([0-9])([0-9])([. _])")" ]; then
		series_season_v1=`echo "$source_filename" | sed 's;\(.*\).\([sS]\)\([0-9]\)\([0-9]\)\([eE]\)\([0-9]\)\([0-9]\).*;Season \3\4;g'`;
		series_season_v2=`echo "$source_filename" | sed 's;\(.*\).\([sS]\)\([0-9]\)\([0-9]\)\([eE]\)\([0-9]\)\([0-9]\).*;Season \3\4;g'`;
		series_title=`echo "$source_filename" | sed 's;\(.*\).\([sS]\)\([0-9]\)\([0-9]\)\([eE]\)\([0-9]\)\([0-9]\).*;\1/;' | sed 's;\(.*\).\([0-9]\)\([0-9]\)\([0-9]\)\([0-9]\).\([0-9]\)\([0-9]\).\([0-9]\)\([0-9]\).*;\1/;'`;
	elif [ "$(echo "$source_filename" | egrep -i "([. _])([0-9])([0-9])([0-9])([0-9]).([0-9])([0-9]).([0-9])([0-9])([. _])")" ]; then
		series_season_v1=`echo "$source_filename" | sed 's;\(.*\).\([0-9]\)\([0-9]\)\([0-9]\)\([0-9]\).\([0-9]\)\([0-9]\).\([0-9]\)\([0-9]\).*;Season \2\3\4\5;g'`;
		series_season_v2=`echo "$source_filename" | sed 's;\(.*\).\([0-9]\)\([0-9]\)\([0-9]\)\([0-9]\).\([0-9]\)\([0-9]\).\([0-9]\)\([0-9]\).*;Season \2\3\4\5;g'`;
		series_title=`echo "$source_filename" | sed 's;\(.*\).\([sS]\)\([0-9]\)\([0-9]\)\([eE]\)\([0-9]\)\([0-9]\).*;\1/;' | sed 's;\(.*\).\([0-9]\)\([0-9]\)\([0-9]\)\([0-9]\).\([0-9]\)\([0-9]\).\([0-9]\)\([0-9]\).*;\1/;'`;
	fi
	
	# Trying to find the path to an existing series
	if [ "$series_title" ] && [ "$tv_shows_post" != "no" ]; then
		series_list=$(ls -d */ "$tv_shows_post_path")
		# Looking for a perfect match
		if [ "$(echo "$series_list" | egrep -i "^$series_title$")" ]; then
			series_title="$(echo -e "$series_list" | egrep -i "^$series_title$" | sed -n '$p')";
		# Trying with or without the prefix
		elif [ "$(echo "$series_list" | egrep -i "$(echo "$series_title" | sed 's;The ;;' | sed 's;Le ;;'| sed 's;La ;;'| sed 's;Les ;;'| sed 's;El ;;' | sed 's;^;(The |Le |La |Les |El ){0,1};' | sed 's;^\(.*\)/$;^\1/$;')")" ]; then
			series_title="$(echo -e "$series_list" | egrep -i "$(echo "$series_title" | sed 's;The ;;' | sed 's;Le ;;'| sed 's;La ;;'| sed 's;Les ;;'| sed 's;El ;;' | sed 's;^;(The |Le |La |Les |El ){0,1};' | sed 's;^\(.*\)$;^\1$;')" | sed -n '$p')";
		# Trying with or without year
		elif [ "$(echo "$series_list" | egrep -i "$(echo "$series_title" | sed 's;The ;;' | sed 's;Le ;;'| sed 's;La ;;'| sed 's;Les ;;'| sed 's;El ;;' | sed 's;^;(The |Le |La |Les |El ){0,1};' | sed 's; \([0-9][0-9][0-9][0-9]\)$;;' | sed 's;$;( [0-9][0-9][0-9][0-9]){0,1};' | sed 's;^\(.*\)/$;^\1/$;')")" ]; then
			series_title="$(echo -e "$series_list" | egrep -i "$(echo "$series_title" | sed 's;The ;;' | sed 's;Le ;;'| sed 's;La ;;'| sed 's;Les ;;'| sed 's;El ;;' | sed 's;^;(The |Le |La |Les |El ){0,1};' | sed 's; \([0-9][0-9][0-9][0-9]\)$;;' | sed 's;$;( [0-9][0-9][0-9][0-9]){0,1};' | sed 's;^\(.*\)/$;^\1/$;')" | sed -n '$p')";
		# Lookup failed. We ll use the episode name
		fi
	fi
	
	# Reverting to default if tv_shows_post_path_mode is disabled
	if [[ "$(echo "$line" | egrep -i "([. _])s([0-9])([0-9])e([0-9])([0-9])([. _])" )" || "$(echo "$line" | egrep -i "([. _])([0-9])([0-9])([0-9])([0-9]).([0-9])([0-9]).([0-9])([0-9])([. _])")" ]] && [ "$(echo "$line" | egrep -i "$tv_show_extensions_rev" )" ] && [[ "$tv_shows_post" != "no" && "$tv_shows_post_path_mode" == "no" ]]; then new_destination=`echo "$tv_shows_post_path"`; fi
	
	# Adding surrounding folder to the destination path variable
	old_destination="$new_destination";
	if [ "$folder_short" ]; then new_destination=`echo "$new_destination$folder_short/"`; fi
	
	# Defining destination path to be /Series/Episode (s) or /Series/Season X/Episode (ss)
	# or /Series/Season XX/Episode (sss) depending on user setting in variable tv_shows_post_path_mode
	if [[ "$(echo "$source_filename" | egrep -i "([. _])s([0-9])([0-9])e([0-9])([0-9])([. _])" )" || "$(echo "$source_filename" | egrep -i "([. _])([0-9])([0-9])([0-9])([0-9]).([0-9])([0-9]).([0-9])([0-9])([. _])")" ]] && [ "$(echo "$line" | egrep -i "$tv_show_extensions_rev" )" ] && [[ "$tv_shows_post" != "no" && "$tv_shows_post_path_mode" == "s" ]]; then
		new_destination=`echo "$tv_shows_post_path$series_title"`;
	elif [[ "$(echo "$source_filename" | egrep -i "([. _])s([0-9])([0-9])e([0-9])([0-9])([. _])" )" || "$(echo "$source_filename" | egrep -i "([. _])([0-9])([0-9])([0-9])([0-9]).([0-9])([0-9]).([0-9])([0-9])([. _])")" ]] && [ "$(echo "$line" | egrep -i "$tv_show_extensions_rev" )" ] && [[ "$tv_shows_post" != "no" && "$tv_shows_post_path_mode" == "ss" ]]; then
		new_destination=`echo "$tv_shows_post_path$series_title$series_season_v1/"`;
	elif [[ "$(echo "$source_filename" | egrep -i "([. _])s([0-9])([0-9])e([0-9])([0-9])([. _])" )" || "$(echo "$source_filename" | egrep -i "([. _])([0-9])([0-9])([0-9])([0-9]).([0-9])([0-9]).([0-9])([0-9])([. _])")" ]] && [ "$(echo "$line" | egrep -i "$tv_show_extensions_rev" )" ] && [[ "$tv_shows_post" != "no" && "$tv_shows_post_path_mode" == "sss" ]]; then
		new_destination=`echo "$tv_shows_post_path$series_title$series_season_v2/"`;
	fi
	
	# Copying TV Shows
	if [[ "$(echo "$source_filename" | egrep -i "([. _])s([0-9])([0-9])e([0-9])([0-9])([. _])" )" || "$(echo "$source_filename" | egrep -i "([. _])([0-9])([0-9])([0-9])([0-9]).([0-9])([0-9]).([0-9])([0-9])([. _])")" ]] && [[ "$(echo "$source_filename" | egrep -i "$tv_show_extensions_rev")" && "$tv_shows_post" == "copy" ]]; then
		new_dest_bis="$(echo "$new_destination" | sed "s;^$tv_shows_post_path;;" | sed "s;/;\\\n;g")";
		dirpath="$tv_shows_post_path";
		for d in $(echo -e "$new_dest_bis"); do
			dirpath="$dirpath$d/"
			if [ ! -d "$dirpath" ] && [[ "$(cat "$temp_folder$additional_permissions" | grep -o "^$dirpath$")" == "" ]]; then
				echo "$dirpath" >> "$temp_folder$additional_permissions";
			fi
		done
		if [ ! -d "$new_destination" ]; then mkdir -p "$new_destination"; fi;
		if [ "$has_display" == "yes" ]; then
				echo "- Copying $source_filename to $new_destination";
		fi
		cp -f "$source_file" "$new_destination"
		echo "$new_destination$source_filename" >> "$temp_folder$additional_permissions"
	
	# Moving TV Shows
	elif [[ "$(echo "$source_filename" | egrep -i "([. _])s([0-9])([0-9])e([0-9])([0-9])([. _])" )" || "$(echo "$source_filename" | egrep -i "([. _])([0-9])([0-9])([0-9])([0-9]).([0-9])([0-9]).([0-9])([0-9])([. _])")" ]] && [[ "$(echo "$source_filename" | egrep -i "$tv_show_extensions_rev")" && "$tv_shows_post" == "move" ]]; then
		new_dest_bis="$(echo "$new_destination" | sed "s;^$tv_shows_post_path;;" | sed "s;/;\\\n;g")";
		dirpath="$tv_shows_post_path";
		for d in $(echo -e "$new_dest_bis"); do
			dirpath="$dirpath$d/"
			if [ ! -d "$dirpath" ] && [[ "$(cat "$temp_folder$additional_permissions" | grep -o "^$dirpath$")" == "" ]]; then
				echo "$dirpath" >> "$temp_folder$additional_permissions";
			fi
		done
		if [ ! -d "$new_destination" ]; then mkdir -p "$new_destination"; fi;
		if [ "$has_display" == "yes" ]; then
			echo "- Moving $source_filename to $new_destination";
		fi
		mv -f "$source_file" "$new_destination";
		echo "$new_destination$source_filename" >> "$temp_folder$additional_permissions";
		if [[ "$gnu_sed_available" == "yes" ]]; then
			sed -i "s;$source_file;$new_destination$source_filename;g" "$log_file";
		else
			sed -i '' "s;$source_file;$new_destination$source_filename;g" "$log_file";
		fi
	
	# Copying Music and movies
    elif [[ "$(echo "$line" | egrep -i "$music_extensions_rev")" && "$music_post" == "copy" ]] || [[ "$(echo "$line" | egrep -i "$movies_extensions_rev")" && "$(echo "$quality" | egrep -i "$movies_detect_patterns_rev" )" && "$movies_post" == "copy" ]] || [[ "$(echo "$line" | egrep -i "$movies_extensions_rev")" && "$(echo "$quality" | egrep -i "$movies_detect_patterns_pt_2_rev" )" && "$movies_post" == "copy" ]] || [[ "$(echo "$line" | egrep -i "$movies_extensions_rev")" && "$(echo "$line" | egrep -i "$movies_detect_patterns_rev" )" && "$movies_post" == "copy" ]] || [[ "$(echo "$line" | egrep -i "$movies_extensions_rev")" && "$(echo "$line" | egrep -i "$movies_detect_patterns_pt_2_rev" )" && "$movies_post" == "copy" ]]; then
    	if [ ! "$folder_short" ] && [[ "$(echo "$line" | egrep -i "$movies_extensions_rev")" && "$force_single_file_movies_folder" == "yes" ]]; then
    		source_trimmed=`echo "$line" | sed 's/\(.*\)\..*/\1/' | sed 's;.*/;;g'`;
    		new_destination=`echo "$new_destination$source_trimmed/"`;
    	fi
    	new_dest_bis="$(echo "$new_destination" | sed "s;^$old_destination;;" | sed "s;/;\\\n;g")";
		dirpath="$old_destination";
		for d in $(echo -e "$new_dest_bis"); do
			dirpath="$dirpath$d/"
			if [ ! -d "$dirpath" ] && [[ "$(cat "$temp_folder$additional_permissions" | grep -o "^$dirpath$")" == "" ]]; then
				echo "$dirpath" >> "$temp_folder$additional_permissions";
			fi
		done
    	if [ ! -d "$new_destination" ]; then mkdir -p "$new_destination"; fi;
    	if [ "$has_display" == "yes" ]; then
    		echo "- Copying $source_filename to $new_destination";
    	fi
    	cp -f "$source_file" "$new_destination"
    	echo "$new_destination$source_filename" >> "$temp_folder$additional_permissions"
    
    # Moving Music and movies
    elif [[ "$(echo "$line" | egrep -i "$music_extensions_rev")" && "$music_post" == "move" ]] || [[ "$(echo "$line" | egrep -i "$movies_extensions_rev")" && "$(echo "$quality" | egrep -i "$movies_detect_patterns_rev" )" && "$movies_post" == "move" ]] || [[ "$(echo "$line" | egrep -i "$movies_extensions_rev")" && "$(echo "$quality" | egrep -i "$movies_detect_patterns_pt_2_rev" )" && "$movies_post" == "move" ]] || [[ "$(echo "$line" | egrep -i "$movies_extensions_rev")" && "$(echo "$line" | egrep -i "$movies_detect_patterns_rev" )" && "$movies_post" == "move" ]] || [[ "$(echo "$line" | egrep -i "$movies_extensions_rev")" && "$(echo "$line" | egrep -i "$movies_detect_patterns_pt_2_rev" )" && "$movies_post" == "move" ]]; then
    	if [ ! "$folder_short" ] && [[ "$(echo "$line" | egrep -i "$movies_extensions_rev")" && "$force_single_file_movies_folder" == "yes" ]]; then
    		source_trimmed=`echo "$line" | sed 's/\(.*\)\..*/\1/' | sed 's;.*/;;g'`;
    		new_destination=`echo "$new_destination$source_trimmed/"`;
    	fi
    	new_dest_bis="$(echo "$new_destination" | sed "s;^$old_destination;;" | sed "s;/;\\\n;g")";
		dirpath="$old_destination";
		for d in $(echo -e "$new_dest_bis"); do
			dirpath="$dirpath$d/"
			if [ ! -d "$dirpath" ] && [[ "$(cat "$temp_folder$additional_permissions" | grep -o "^$dirpath$")" == "" ]]; then
				echo "$dirpath" >> "$temp_folder$additional_permissions";
			fi
		done
    	if [ ! -d "$new_destination" ]; then mkdir -p "$new_destination"; fi;
    	if [ "$has_display" == "yes" ]; then
    		echo "- Moving $source_filename to $new_destination";
    	fi
    	mv -f "$source_file" "$new_destination"
    	echo "$new_destination$source_filename" >> "$temp_folder$additional_permissions"
    	if [[ "$gnu_sed_available" == "yes" ]]; then
    		sed -i "s;$source_file;$new_destination$source_filename;g" "$log_file";
    	else
    		sed -i '' "s;$source_file;$new_destination$source_filename;g" "$log_file";
    	fi
	fi
	series_title="";
	series_season_v1="";
	series_season_v2="";
done
fi


## Deleting unnecessary surrounding folder
if [[ "$folder_short" && -d "$temp_folder$folder_short" ]]; then
	files_in_folder_short=$(ls -1 "$temp_folder$folder_short" | wc -l)
	if [[ "$music_post" == "move" && $files_in_folder_short -eq 0 ]] || [[ "$tv_shows_post" == "move" && $files_in_folder_short -eq 0 ]] || [[ "$movies_post" == "move" && $files_in_folder_short -eq 0 ]]; then rm -rf "$temp_folder$folder_short" && folder_short="" && echo > "$log_file"; fi
fi


## Move content of temp folder to destination folder
if [[ "$folder_short" && "$script_failed" != "yes" ]]; then
	count=1
	dest=`echo "$destination_folder$folder_short"`
	# Adding a number into brackets if there s already a directory with the same name
	while [ -d "$dest" ]; do
		if [[ count -eq 1 ]] || [ "$subtitles_mode" == "yes" ]; then
			dest=`echo "$destination_folder$folder_short"`;
		else
			dest=`echo "$destination_folder$folder_short [$count]"`;
		fi
		count=$(( count + 1 ))
	done
	# Moving the directory while renaming it with the optional number into brackets
	mv -f "$temp_folder$folder_short" "$dest"
		if [[ "$gnu_sed_available" == "yes" ]]; then
    		sed -i "s;^$temp_folder$folder_short;$dest;g" "$log_file";
    	else
    		sed -i '' "s;^$temp_folder$folder_short;$dest;g" "$log_file";
    	fi
    folder_short=`echo "$( basename "$dest" )"`
elif [[ ! "$folder_short" && "$script_failed" != "yes" ]]; then
	for line in $(cat "$log_file"); do
		item=`echo "$line"`;
		title_clean=`echo "$(basename "$item")" | sed 's/\(.*\)\..*/\1/'`
		extension=`echo "$item" | sed 's;.*\.;.;'`
		count=1
		dest=`echo "$destination_folder$title_clean$extension"`
		# Adding a number into brackets if there s already a file with the same name
		while [ -f "$dest" ]; do
			if [[ count -eq 1 ]] || [ "$subtitles_mode" == "yes" ]; then
				dest=`echo "$destination_folder$title_clean$extension"`;
			else
				dest=`echo "$destination_folder$title_clean [$count]$extension"`;
			fi
			count=$(( count + 1 ))
		done
		# Moving the file while renaming it with the optional number into brackets
		if [[ "$(echo "$line" | egrep -i "$temp_folder")" && -f "$item" ]]; then mv -f "$item" "$dest"; fi
		if [[ "$gnu_sed_available" == "yes" ]]; then
    		sed -i "s;^$item$;$dest;g" "$log_file";
    	else
    		sed -i '' "s;^$item$;$dest;g" "$log_file";
    	fi
	done
fi


## Removing the temp directory and edit the log_file accordingly
if [ -f "$temp_folder$additional_permissions" ]; then additional_list="$(cat "$temp_folder$additional_permissions")"; fi
if [[ "$gnu_sed_available" != "yes" ]]; then rm -rf "$temp_folder_without_slash" && sed -i '' "s;^$temp_folder;$destination_folder;g" "$log_file"; else rm -rf "$temp_folder_without_slash" && sed -i "s;^$temp_folder;$destination_folder;g" "$log_file"; fi


## Edit files and folders permissions
if [ "$folder_short" ]; then echo "$destination_folder$folder_short" >> "$log_file"; fi
all_files_list="$(echo -e "$(cat "$log_file")\n$additional_list")"
if [[ "$has_display" == "yes" && "$user_perm_post" != "no" ]] || [[ "$has_display" == "yes" && "$files_perm_post" != "no" ]]; then step_number=$(( $step_number + 1 )) && echo "Step $step_number : Setting permissions";  fi

# Taking care of file and folders permissions
for line in $(echo -e "$all_files_list"); do
	if [[ "$user_perm_post" != "no" && "$group_perm_post" != "no" ]] || [[ "$files_perm_post" != "no" && "$folder_perm_post" != "no" ]]; then
		# Chmod part of the routine
		item=`echo "$line"`
		if [ "$item" == "" ]; then
			echo > /dev/null 2>&1
		# Chmod files
		elif [[ -f "$item" && "$files_perm_post" != "no" ]]; then
			chmod "$files_perm_post" "$item"
		# Chmod directories
		elif [[ -d "$item" && "$folder_perm_post" != "no" ]]; then
			chmod "$folder_perm_post" "$item"
		fi
		# Chown part of the routine
		if [ "$item" == "" ]; then
			echo > /dev/null 2>&1
		# Chown files and directories if run as root
		elif [[ $(id -u) -eq 0 && "$user_perm_post" != "no" && "$group_perm_post" != "no" ]] && [[ -f "$item" || -d "$item" ]]; then
			chown "$user_perm_post":"$group_perm_post" "$item"
		# Chown files and directories with sudo if user interaction is available
		elif [[ "$edit_perm_as_sudo" == "yes" && "$has_display" == "yes" && "$user_perm_post" != "no" && "$group_perm_post" != "no" ]] && [[ -f "$item" || -d "$item" ]]; then
			sudo chown "$user_perm_post":"$group_perm_post" "$item"
		fi
	fi
done


## Reset timestamp (mtime)
## Modification time of the file will be set to the moment the script ends. Useful to find the latest downloads
if [ "$has_display" == "yes" ] && [ "$reset_timestamp" == "yes" ]; then step_number=$(( $step_number + 1 )) && echo "Step $step_number : Resetting mtime";  fi
# setting mtime for files
for line in $(echo -e "$all_files_list"); do
	if [ "$reset_timestamp" == "yes" ]; then
		item=`echo "$line"`
		touch "$line"
	fi
done


## Use a source / destination log shared with a third party app - Add path to enable
count=0 && files=$(( $count + $(cat "$log_file"|wc -l) ))
# If only one file, add its path to the third_party_log file
if [[ $files -eq 0 ]] && [ "$third_party_log" != "no" ] && [ "$subtitles_mode" != "yes" ]; then echo "" > "$third_party_log"; fi
if [[ $files -eq 1 ]] && [ "$third_party_log" != "no" ] && [ "$subtitles_mode" != "yes" ]; then echo "$(cat "$log_file")" > "$third_party_log"; fi
if [[ $files -gt 1 ]] && [ "$third_party_log" != "no" ] && [ "$subtitles_mode" != "yes" ]; then folder_name=`echo "$destination_folder$folder_short"`; echo "$folder_name" > "$third_party_log"; fi
# If we end up with a directory, add its path to the third_party_log file
if [ "$third_party_log" != "no" ] && [ "$user_perm_post" == "yes" ] && [ "$subtitles_mode" != "yes" ]; then chown "$user_perm_post":"$group_perm_post" "$third_party_log" && sudo chmod "$files_perm_post" "$third_party_log"; fi

## Delete third party log if required
if [ "$delete_third_party_log" == "yes" ] && [ "$third_party_log" != "no" ] && [ "$subtitles_mode" != "yes" ]; then rm -f "$third_party_log"; fi


##################################################################################
## Starting the all_files_script and processed_torrent_script

if [[ "$has_display" == "yes" && "$all_files_script_enabled" == "yes" ]] || [[ "$has_display" == "yes" && "$processed_torrent_script_enabled" == "yes" ]]; then step_number=$(( $step_number + 1 )) && echo "Step $step_number : Running custom scripts";  fi


# Consolidating files list
for line in $(echo -e "$additional_list"); do
	if [ -f "$line" ]; then
		for line2 in $(cat "$log_file"); do
			line="$(echo "$line" | grep -v "$(basename "$line2")")"
		done
		if [ "$line" ]; then 
			files_list="$files_list\n$line"
		fi
	fi
done
for line in $(cat "$log_file"); do
	if [ -f "$line" ]; then
		files_list="$files_list\n$line"
	fi
done

# Correcting IMDB title
if [ "$imdb_title" ]; then imdb_title="$(echo $imdb_title | sed 's;%28;(;g' | sed 's;%29;);g' | sed 's;\+; ;g' | sed "s;%20; ;g")"; fi

# Setting IMDB and TMDB variables for all_files_script
if [ "$all_files_script_variable_1" == "imdb_title" ]; then
		all_files_script_variable_1="$imdb_title";
	elif [ "$all_files_script_variable_1" == "imdb_url" ]; then
		all_files_script_variable_1="$imdb_url";
	elif [ "$all_files_script_variable_1" == "imdb_id" ]; then
		all_files_script_variable_1="$imdb_id";
	elif [ "$all_files_script_variable_1" == "poster_url" ]; then
		all_files_script_variable_1="$poster_url";
	elif [ "$all_files_script_variable_1" == "fanart_url" ]; then
		all_files_script_variable_1="$fanart_url";
fi
if [ "$all_files_script_variable_2" == "imdb_title" ]; then
		all_files_script_variable_2="$imdb_title";
	elif [ "$all_files_script_variable_2" == "imdb_url" ]; then
		all_files_script_variable_2="$imdb_url";
	elif [ "$all_files_script_variable_2" == "imdb_id" ]; then
		all_files_script_variable_2="$imdb_id";
	elif [ "$all_files_script_variable_2" == "poster_url" ]; then
		all_files_script_variable_2="$poster_url";
	elif [ "$all_files_script_variable_2" == "fanart_url" ]; then
		all_files_script_variable_2="$fanart_url";
fi
if [ "$all_files_script_variable_3" == "imdb_title" ]; then
		all_files_script_variable_3="$imdb_title";
	elif [ "$all_files_script_variable_3" == "imdb_url" ]; then
		all_files_script_variable_3="$imdb_url";
	elif [ "$all_files_script_variable_3" == "imdb_id" ]; then
		all_files_script_variable_3="$imdb_id";
	elif [ "$all_files_script_variable_3" == "poster_url" ]; then
		all_files_script_variable_3="$poster_url";
	elif [ "$all_files_script_variable_3" == "fanart_url" ]; then
		all_files_script_variable_3="$fanart_url";
fi
if [ "$all_files_script_variable_4" == "imdb_title" ]; then
		all_files_script_variable_4="$imdb_title";
	elif [ "$all_files_script_variable_4" == "imdb_url" ]; then
		all_files_script_variable_4="$imdb_url";
	elif [ "$all_files_script_variable_4" == "imdb_id" ]; then
		all_files_script_variable_4="$imdb_id";
	elif [ "$all_files_script_variable_4" == "poster_url" ]; then
		all_files_script_variable_4="$poster_url";
	elif [ "$all_files_script_variable_4" == "fanart_url" ]; then
		all_files_script_variable_4="$fanart_url";
fi
if [ "$all_files_script_variable_5" == "imdb_title" ]; then
		all_files_script_variable_5="$imdb_title";
	elif [ "$all_files_script_variable_5" == "imdb_url" ]; then
		all_files_script_variable_5="$imdb_url";
	elif [ "$all_files_script_variable_5" == "imdb_id" ]; then
		all_files_script_variable_5="$imdb_id";
	elif [ "$all_files_script_variable_5" == "poster_url" ]; then
		all_files_script_variable_5="$poster_url";
	elif [ "$all_files_script_variable_5" == "fanart_url" ]; then
		all_files_script_variable_5="$fanart_url";
fi

# Setting IMDB and TMDB variables for processed_torrent_script
if [ "$processed_torrent_script_variable_1" == "imdb_title" ]; then
		processed_torrent_script_variable_1="$imdb_title";
	elif [ "$processed_torrent_script_variable_1" == "imdb_url" ]; then
		processed_torrent_script_variable_1="$imdb_url";
	elif [ "$processed_torrent_script_variable_1" == "imdb_id" ]; then
		processed_torrent_script_variable_1="$imdb_id";
	elif [ "$processed_torrent_script_variable_1" == "poster_url" ]; then
		processed_torrent_script_variable_1="$poster_url";
	elif [ "$processed_torrent_script_variable_1" == "fanart_url" ]; then
		processed_torrent_script_variable_1="$fanart_url";
fi
if [ "$processed_torrent_script_variable_2" == "imdb_title" ]; then
		processed_torrent_script_variable_2="$imdb_title";
	elif [ "$processed_torrent_script_variable_2" == "imdb_url" ]; then
		processed_torrent_script_variable_2="$imdb_url";
	elif [ "$processed_torrent_script_variable_2" == "imdb_id" ]; then
		processed_torrent_script_variable_2="$imdb_id";
	elif [ "$processed_torrent_script_variable_2" == "poster_url" ]; then
		processed_torrent_script_variable_2="$poster_url";
	elif [ "$processed_torrent_script_variable_2" == "fanart_url" ]; then
		processed_torrent_script_variable_2="$fanart_url";
fi
if [ "$processed_torrent_script_variable_3" == "imdb_title" ]; then
		processed_torrent_script_variable_3="$imdb_title";
	elif [ "$processed_torrent_script_variable_3" == "imdb_url" ]; then
		processed_torrent_script_variable_3="$imdb_url";
	elif [ "$processed_torrent_script_variable_3" == "imdb_id" ]; then
		processed_torrent_script_variable_3="$imdb_id";
	elif [ "$processed_torrent_script_variable_3" == "poster_url" ]; then
		processed_torrent_script_variable_3="$poster_url";
	elif [ "$processed_torrent_script_variable_3" == "fanart_url" ]; then
		processed_torrent_script_variable_3="$fanart_url";
fi
if [ "$processed_torrent_script_variable_4" == "imdb_title" ]; then
		processed_torrent_script_variable_4="$imdb_title";
	elif [ "$processed_torrent_script_variable_4" == "imdb_url" ]; then
		processed_torrent_script_variable_4="$imdb_url";
	elif [ "$processed_torrent_script_variable_4" == "imdb_id" ]; then
		processed_torrent_script_variable_4="$imdb_id";
	elif [ "$processed_torrent_script_variable_4" == "poster_url" ]; then
		processed_torrent_script_variable_4="$poster_url";
	elif [ "$processed_torrent_script_variable_4" == "fanart_url" ]; then
		processed_torrent_script_variable_4="$fanart_url";
fi
if [ "$processed_torrent_script_variable_5" == "imdb_title" ]; then
		processed_torrent_script_variable_5="$imdb_title";
	elif [ "$processed_torrent_script_variable_5" == "imdb_url" ]; then
		processed_torrent_script_variable_5="$imdb_url";
	elif [ "$processed_torrent_script_variable_5" == "imdb_id" ]; then
		processed_torrent_script_variable_5="$imdb_id";
	elif [ "$processed_torrent_script_variable_5" == "poster_url" ]; then
		processed_torrent_script_variable_5="$poster_url";
	elif [ "$processed_torrent_script_variable_5" == "fanart_url" ]; then
		processed_torrent_script_variable_5="$fanart_url";
fi

# Running the all_files_script
if [[ "$all_files_script_enabled" == "yes" && -x "$all_files_script" ]] || [[ "$all_files_script_enabled" == "yes" && -x "$(which "$all_files_script")" ]]; then
	for file_path in $(echo -e "$files_list"); do
		name_with_extension="$(basename "$file_path")"
		name_without_extension="$(echo "$name_with_extension" | sed 's/\(.*\)\..\{3,4\}$/\1/')"
		if [ -e "$file_path" ] && [ "$all_files_script_variable_5" ]; then
			"$all_files_script" "$(if [ "$all_files_script_variable_1" == "file_path" ]; then echo "$file_path"; elif [ "$all_files_script_variable_1" == "name_with_extension" ]; then echo "$name_with_extension"; elif [ "$all_files_script_variable_1" == "name_without_extension" ]; then echo "$name_without_extension"; else echo "$all_files_script_variable_1"; fi)" "$(if [ "$all_files_script_variable_2" == "file_path" ]; then echo "$file_path"; elif [ "$all_files_script_variable_2" == "name_with_extension" ]; then echo "$name_with_extension"; elif [ "$all_files_script_variable_2" == "name_without_extension" ]; then echo "$name_without_extension"; else echo "$all_files_script_variable_2"; fi)" "$(if [ "$all_files_script_variable_3" == "file_path" ]; then echo "$file_path"; elif [ "$all_files_script_variable_3" == "name_with_extension" ]; then echo "$name_with_extension"; elif [ "$all_files_script_variable_3" == "name_without_extension" ]; then echo "$name_without_extension"; else echo "$all_files_script_variable_3"; fi)" "$(if [ "$all_files_script_variable_4" == "file_path" ]; then echo "$file_path"; elif [ "$all_files_script_variable_4" == "name_with_extension" ]; then echo "$name_with_extension"; elif [ "$all_files_script_variable_4" == "name_without_extension" ]; then echo "$name_without_extension"; else echo "$all_files_script_variable_4"; fi)" "$(if [ "$all_files_script_variable_5" == "file_path" ]; then echo "$file_path"; elif [ "$all_files_script_variable_5" == "name_with_extension" ]; then echo "$name_with_extension"; elif [ "$all_files_script_variable_5" == "name_without_extension" ]; then echo "$name_without_extension"; else echo "$all_files_script_variable_5"; fi)"
		elif [ -e "$file_path" ] && [ "$all_files_script_variable_4" ]; then
			"$all_files_script" "$(if [ "$all_files_script_variable_1" == "file_path" ]; then echo "$file_path"; elif [ "$all_files_script_variable_1" == "name_with_extension" ]; then echo "$name_with_extension"; elif [ "$all_files_script_variable_1" == "name_without_extension" ]; then echo "$name_without_extension"; else echo "$all_files_script_variable_1"; fi)" "$(if [ "$all_files_script_variable_2" == "file_path" ]; then echo "$file_path"; elif [ "$all_files_script_variable_2" == "name_with_extension" ]; then echo "$name_with_extension"; elif [ "$all_files_script_variable_2" == "name_without_extension" ]; then echo "$name_without_extension"; else echo "$all_files_script_variable_2"; fi)" "$(if [ "$all_files_script_variable_3" == "file_path" ]; then echo "$file_path"; elif [ "$all_files_script_variable_3" == "name_with_extension" ]; then echo "$name_with_extension"; elif [ "$all_files_script_variable_3" == "name_without_extension" ]; then echo "$name_without_extension"; else echo "$all_files_script_variable_3"; fi)" "$(if [ "$all_files_script_variable_4" == "file_path" ]; then echo "$file_path"; elif [ "$all_files_script_variable_4" == "name_with_extension" ]; then echo "$name_with_extension"; elif [ "$all_files_script_variable_4" == "name_without_extension" ]; then echo "$name_without_extension"; else echo "$all_files_script_variable_4"; fi)"
		elif [ -e "$file_path" ] && [ "$all_files_script_variable_3" ]; then
			"$all_files_script" "$(if [ "$all_files_script_variable_1" == "file_path" ]; then echo "$file_path"; elif [ "$all_files_script_variable_1" == "name_with_extension" ]; then echo "$name_with_extension"; elif [ "$all_files_script_variable_1" == "name_without_extension" ]; then echo "$name_without_extension"; else echo "$all_files_script_variable_1"; fi)" "$(if [ "$all_files_script_variable_2" == "file_path" ]; then echo "$file_path"; elif [ "$all_files_script_variable_2" == "name_with_extension" ]; then echo "$name_with_extension"; elif [ "$all_files_script_variable_2" == "name_without_extension" ]; then echo "$name_without_extension"; else echo "$all_files_script_variable_2"; fi)" "$(if [ "$all_files_script_variable_3" == "file_path" ]; then echo "$file_path"; elif [ "$all_files_script_variable_3" == "name_with_extension" ]; then echo "$name_with_extension"; elif [ "$all_files_script_variable_3" == "name_without_extension" ]; then echo "$name_without_extension"; else echo "$all_files_script_variable_3"; fi)"
		elif [ -e "$file_path" ] && [ "$all_files_script_variable_2" ]; then
			"$all_files_script" "$(if [ "$all_files_script_variable_1" == "file_path" ]; then echo "$file_path"; elif [ "$all_files_script_variable_1" == "name_with_extension" ]; then echo "$name_with_extension"; elif [ "$all_files_script_variable_1" == "name_without_extension" ]; then echo "$name_without_extension"; else echo "$all_files_script_variable_1"; fi)" "$(if [ "$all_files_script_variable_2" == "file_path" ]; then echo "$file_path"; elif [ "$all_files_script_variable_2" == "name_with_extension" ]; then echo "$name_with_extension"; elif [ "$all_files_script_variable_2" == "name_without_extension" ]; then echo "$name_without_extension"; else echo "$all_files_script_variable_2"; fi)"
		else
			"$all_files_script" "$(if [ "$all_files_script_variable_1" == "name_with_extension" ]; then echo "$name_with_extension"; elif [ "$all_files_script_variable_1" == "name_without_extension" ]; then echo "$name_without_extension"; else echo "$file_path"; fi)"
		fi
	done
fi

# Setting file_path for processed_torrent_script
count=0 && files=$(( $count + $(cat "$log_file"|wc -l) ))
if [[ $files -eq 1 ]]; then
	file_path="$(cat "$log_file")";
elif [[ $files -gt 1 ]]; then
	file_path=`echo "$destination_folder$folder_short"`;
fi

# Running the processed_files_script
if [[ "$processed_torrent_script_enabled" == "yes" && -x "$processed_torrent_script" ]] || [[ "$processed_torrent_script_enabled" == "yes" && -x "$(which "$processed_torrent_script")" ]]; then
	name_with_extension="$(basename "$file_path")"
	name_without_extension="$(echo "$name_with_extension" | sed 's/\(.*\)\..\{3,4\}$/\1/')"
	if [ -e "$file_path" ] && [ "$processed_torrent_script_variable_5" ]; then
		"$processed_torrent_script" "$(if [ "$processed_torrent_script_variable_1" == "file_path" ]; then echo "$file_path"; elif [ "$processed_torrent_script_variable_1" == "name_with_extension" ]; then echo "$name_with_extension"; elif [ "$processed_torrent_script_variable_1" == "name_without_extension" ]; then echo "$name_without_extension"; else echo "$processed_torrent_script_variable_1"; fi)" "$(if [ "$processed_torrent_script_variable_2" == "file_path" ]; then echo "$file_path"; elif [ "$processed_torrent_script_variable_2" == "name_with_extension" ]; then echo "$name_with_extension"; elif [ "$processed_torrent_script_variable_2" == "name_without_extension" ]; then echo "$name_without_extension"; else echo "$processed_torrent_script_variable_2"; fi)" "$(if [ "$processed_torrent_script_variable_3" == "file_path" ]; then echo "$file_path"; elif [ "$processed_torrent_script_variable_3" == "name_with_extension" ]; then echo "$name_with_extension"; elif [ "$processed_torrent_script_variable_3" == "name_without_extension" ]; then echo "$name_without_extension"; else echo "$processed_torrent_script_variable_3"; fi)" "$(if [ "$processed_torrent_script_variable_4" == "file_path" ]; then echo "$file_path"; elif [ "$processed_torrent_script_variable_4" == "name_with_extension" ]; then echo "$name_with_extension"; elif [ "$processed_torrent_script_variable_4" == "name_without_extension" ]; then echo "$name_without_extension"; else echo "$processed_torrent_script_variable_4"; fi)" "$(if [ "$processed_torrent_script_variable_5" == "file_path" ]; then echo "$file_path"; elif [ "$processed_torrent_script_variable_5" == "name_with_extension" ]; then echo "$name_with_extension"; elif [ "$processed_torrent_script_variable_5" == "name_without_extension" ]; then echo "$name_without_extension"; else echo "$processed_torrent_script_variable_5"; fi)"
	elif [ -e "$file_path" ] && [ "$processed_torrent_script_variable_4" ]; then
		"$processed_torrent_script" "$(if [ "$processed_torrent_script_variable_1" == "file_path" ]; then echo "$file_path"; elif [ "$processed_torrent_script_variable_1" == "name_with_extension" ]; then echo "$name_with_extension"; elif [ "$processed_torrent_script_variable_1" == "name_without_extension" ]; then echo "$name_without_extension"; else echo "$processed_torrent_script_variable_1"; fi)" "$(if [ "$processed_torrent_script_variable_2" == "file_path" ]; then echo "$file_path"; elif [ "$processed_torrent_script_variable_2" == "name_with_extension" ]; then echo "$name_with_extension"; elif [ "$processed_torrent_script_variable_2" == "name_without_extension" ]; then echo "$name_without_extension"; else echo "$processed_torrent_script_variable_2"; fi)" "$(if [ "$processed_torrent_script_variable_3" == "file_path" ]; then echo "$file_path"; elif [ "$processed_torrent_script_variable_3" == "name_with_extension" ]; then echo "$name_with_extension"; elif [ "$processed_torrent_script_variable_3" == "name_without_extension" ]; then echo "$name_without_extension"; else echo "$processed_torrent_script_variable_3"; fi)" "$(if [ "$processed_torrent_script_variable_4" == "file_path" ]; then echo "$file_path"; elif [ "$processed_torrent_script_variable_4" == "name_with_extension" ]; then echo "$name_with_extension"; elif [ "$processed_torrent_script_variable_4" == "name_without_extension" ]; then echo "$name_without_extension"; else echo "$processed_torrent_script_variable_4"; fi)"
	elif [ -e "$file_path" ] && [ "$processed_torrent_script_variable_3" ]; then
		"$processed_torrent_script" "$(if [ "$processed_torrent_script_variable_1" == "file_path" ]; then echo "$file_path"; elif [ "$processed_torrent_script_variable_1" == "name_with_extension" ]; then echo "$name_with_extension"; elif [ "$processed_torrent_script_variable_1" == "name_without_extension" ]; then echo "$name_without_extension"; else echo "$processed_torrent_script_variable_1"; fi)" "$(if [ "$processed_torrent_script_variable_2" == "file_path" ]; then echo "$file_path"; elif [ "$processed_torrent_script_variable_2" == "name_with_extension" ]; then echo "$name_with_extension"; elif [ "$processed_torrent_script_variable_2" == "name_without_extension" ]; then echo "$name_without_extension"; else echo "$processed_torrent_script_variable_2"; fi)" "$(if [ "$processed_torrent_script_variable_3" == "file_path" ]; then echo "$file_path"; elif [ "$processed_torrent_script_variable_3" == "name_with_extension" ]; then echo "$name_with_extension"; elif [ "$processed_torrent_script_variable_3" == "name_without_extension" ]; then echo "$name_without_extension"; else echo "$processed_torrent_script_variable_3"; fi)"
	elif [ -e "$file_path" ] && [ "$processed_torrent_script_variable_2" ]; then
		"$processed_torrent_script" "$(if [ "$processed_torrent_script_variable_1" == "file_path" ]; then echo "$file_path"; elif [ "$processed_torrent_script_variable_1" == "name_with_extension" ]; then echo "$name_with_extension"; elif [ "$processed_torrent_script_variable_1" == "name_without_extension" ]; then echo "$name_without_extension"; else echo "$processed_torrent_script_variable_1"; fi)" "$(if [ "$processed_torrent_script_variable_2" == "file_path" ]; then echo "$file_path"; elif [ "$processed_torrent_script_variable_2" == "name_with_extension" ]; then echo "$name_with_extension"; elif [ "$processed_torrent_script_variable_2" == "name_without_extension" ]; then echo "$name_without_extension"; else echo "$processed_torrent_script_variable_2"; fi)"
	else
		"$processed_torrent_script" "$(if [ "$processed_torrent_script_variable_1" == "name_with_extension" ]; then echo "$name_with_extension"; elif [ "$processed_torrent_script_variable_1" == "name_without_extension" ]; then echo "$name_without_extension"; else echo "$file_path"; fi)"
	fi
fi


## Restore running environment
export TR_TORRENT_DIR=""
export TR_TORRENT_NAME=""
export torrent=""
rm -f "$log_file"

## This is the subtitles routine. If srt files are found in the subtitles directory, they will be renamed and moved to the destination folder
if [[ "$subtitles_mode" != "yes" && "$subtitles_handling" != "no" && -d "$subtitles_directory" && "$(find "$subtitles_directory" -maxdepth 1 ! -name "._*" -name "*.srt" -type f)" ]]; then
 	if [ "$has_display" == "yes" ]; then step_number=$(( $step_number + 1 )) && echo "Step $step_number : Fetching new subtitles from the subtitles folder";  fi
 	export subtitles_mode="yes"
 	has_display="no"
 	# Remove invisible Mac OS X files from the subtitles folder
	for line in $(find "$subtitles_directory" -maxdepth 1 ); do
		item=`echo "$line"`
 		if [[ "$item" == */.AppleDouble* ]] || [[ "$item" == */._* ]] || [[ "$item" == */.DS_Store* ]]; then rm -rf "$item"; fi
 	done
 	# Find subtitles that are available in the subtitles folder
 	for line in $(find "$subtitles_directory" -maxdepth 1 ! -name "._*" -name "*.srt" -type f); do
 		line=`echo "$line"`
 		item=`echo "$(basename "$line")"`
 		item_bis=`echo "$item" | sed 's/\(.*\)\..*/\1/'`
 		# If a subtitle is found, find the corresponding dummy video file
 		orig_file=`echo "$(find "$subtitles_directory" -name "$item_bis.*" -type f | egrep -i "\.avi$|\.mkv$|\.divx$|\.mp4$|\.ts$")"`
 		new_line=`echo "$(cat "$orig_file" | sed '/^ *$/d' | sed 's/\(.*\)\..*/\1\.srt/')"`
 		# We'll now run this subtitle through torrentexpander once again in order to rename it and move it
 		# where the movie already is
 		if [ "$line" != "$new_line" ]; then mv "$line" "$new_line"; fi
 		"$script_path/torrentexpander.sh" "$new_line" "$destination_folder"
 		# Removing the subtitle from the srt folder
 		rm -f "$new_line"
 		# Removing the dummy video file
 		rm -f "$orig_file"
 		# Removing dummy video files older than 30 days
 		find "$subtitles_directory" -mtime +30 -exec rm -f {} \;
 	done
 	if [ -t 1 ]; then echo "That's All Folks"; fi
fi

# Notifying the used that the script is done
if [ "$has_display" == "yes" ]; then echo "That's All Folks";  fi

# Resetting exported variables
export subtitles_mode=""
export script_updated=""
export TR_TORRENT_DIR=""
export TR_TORRENT_NAME=""
IFS=$SAVEIFS
export PATH="$path_backup"

## Starting the post_run_script
if [[ "$post_run_script_enabled" == "yes" && -x "$post_run_script" ]] || [[ "$post_run_script_enabled" == "yes" && -x "$(which "$post_run_script")" ]]; then
	. "$post_run_script"
	sleep 1
fi
