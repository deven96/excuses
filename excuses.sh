#!/usr/bin/env bash

## Colors
RED='\033[0;31m\033[5m'
GREEN='\033[40;38;5;82m'
BLUE='\033[0;34m'
# Normal escapes back to normal text
NORMAL='\033[0m'
EXCUSESARRAY=(
  "to eat food" 
  "for some away screen time" 
  "as I have a slight headache" 
  "to take a rest"
  "for the next one hour"
  "for a bit to run some errands"
)
# Seed random generator
# The number of seconds elapsed since 01/01/1970 is `date +%s`.
RANDOM=$(date +%s)


function checkOS {
  unameOut="$(uname -s)"
  
  case "${unameOut}" in
    Linux*)   machine=Linux;;
    Darwin*)  machine=Mac;;
    *)        echo -e "${RED}Cannot run on unsupported machine ${unameOut}${NORMAL}" && exit 1;
  esac
}

# screenActive=1 means the screen is active
# Mac variant to check if screen is locked
function checkScreenLockedMac {
  python -c 'import sys,Quartz;\
    d=Quartz.CGSessionCopyCurrentDictionary();\
    sys.exit(d and \
      d.get("CGSSessionScreenIsLocked", 0) == 0 and \
      d.get("kCGSSessionOnConsoleKey", 0) == 1)\'
  screenActive=$?
}

testCheckScreenLockedMac() {
  /System/Library/CoreServices/Menu\ Extras/User.menu/Contents/Resources/CGSession -suspend && sleep 5 && 
   checkScreenLockedMac
  if [[ "$screenActive" != "0" ]]; then
    echo -e "${RED}Did not detect screen was locked${NORMAL}";
  else
    echo -e "${GREEN}Detected screen was locked${NORMAL}";
  fi
}


# Linux variant to check if screen is locked
function checkScreenLockedLinux {
  gnome-screensaver-command -q | grep -q "is active"
  if [[ "$?" == "1" ]]; then
    screenActive=0
  else
    screenActive=1
  fi
}

testCheckScreenLockedLinux() {
  gnome-screensaver-command -l && sleep 5 &&
   checkScreenLockedLinux
  if [[ "$screenActive" != "0" ]]; then
    echo -e "${RED}Did not detect screen was locked${NORMAL}";
  else
    echo -e "${GREEN}Detected screen was locked${NORMAL}";
  fi
}

function selectRandomExcuse {
  randomExcuse=${EXCUSESARRAY[$RANDOM % ${#EXCUSESARRAY[@]} ]}
}

elementIn(){
  local e match="$1"
  shift
  for e; do
    [[ "$e" == "$match" ]] && return 0; done
  return 1;
}

testSelectRandomExcuse() {
  selectRandomExcuse
  # check excuses in array
  elementIn "${randomExcuse}" "${EXCUSESARRAY[@]}"
  if [[ $? == 0 ]]; then
    echo -e "${GREEN}Selected Random Excuse '${randomExcuse}' ${NORMAL}"
  else
    echo -e "${RED}Did not select random excuse${NORMAL}";
  fi
}

# replaces the $x variable
# e.g replaceVariable first_locked 7777 ./example.txt 
# will replace any export first_locked=* with export first_locked=7777 directly in ./example.txt
function replaceVariableInFile {
  sed -i -e "s/^export\ $1=.*/export\ $1=$2/g" $3
  # matches .bashrc and .zshrc files
  if [[ "$3" =~ .*"rc" ]]; then
    source $3 && echo -e "${GREEN}Sourced .rc file${NORMAL}"
  fi
}

# check if a variable export is in a file
function checkOrIncludeVariable {
  grep -q "^export\ $1=.*" $2 || echo "export $1=0" >> $2
  source $2
}

# run function passed to this if we are in work period
# e.g runIfWorkPeriod sendMessageToSlackChannel "Hello bob"
function runIfWorkPeriod {
  currenttime=$(date +%H:%M)
  if [[ "$currenttime" > "$start_time" ]] && [[ "$currenttime" < "$end_time" ]]; then
    echo "In work period $currenttime"
    "$@"
  fi
}

function sendMessageToSlackChannel {
  echo -e "${BLUE}Attempting send to Slack channel${NORMAL}"
  ./slack.sh "$1"
  replaceVariableInFile slack_message_sent "$1" $rc_file
}

function checkSlackUtilityExists {
  if [ -f "./slack.sh" ]; then
    chmod +x ./slack.sh
  else
    echo -e "${GREEN}Downloading slack utility...${NORMAL}" &&
    curl -o ./slack.sh https://gist.githubusercontent.com/andkirby/67a774513215d7ba06384186dd441d9e/raw/c8a47aec0f08ca6dc64201ba40f09ff8c79f735e/slack.sh -s && chmod +x ./slack.sh &&
    echo -e "${GREEN}Complete!${NORMAL}"
  fi
}
helpFunction() {              
  echo -e "${BLUE}Usage: $0 -p ~/.bashrc"
  echo -e "\t-p Specify rc file to put variables in (default: ~/.bashrc)"
  echo -e "\t-s Start time at work (default: '09:00')"
  echo -e "\t-e End time at work (default: '18:00')"
  echo -e "\t-m Max seconds after computer sleeps to send excuse (default: 3600)"
  echo -e "\t-h Print this help message"              
  echo -e "\n"
  echo -e "\t Configure the following env variables for slack
     - export APP_SLACK_WEBHOOK="https://XXXXXX"
     - export APP_SLACK_CHANNEL="general" (optional)
     - export APP_SLACK_USERNAME="deven96" (optional)
     - export APP_SLACK_ICON_EMOJI="" (optional)
      ${NORMAL}"
  exit 1                               
   }

function main() {
  # first check variable in bashrc or initialize to zero
  checkOrIncludeVariable first_locked $rc_file
  checkOrIncludeVariable second_locked $rc_file
  checkOrIncludeVariable slack_message_sent $rc_file
  checkOS
  checkScreenLocked$machine
  # check slack utility exists
  checkSlackUtilityExists
  if [[ "$screenActive" == "1" ]]; then
    echo -e "${BLUE}Found screen activity${NORMAL}"
    # screen is now active, initialize to 0
    replaceVariableInFile first_locked 0 $rc_file &&
    replaceVariableInFile second_locked 0 $rc_file &&
    replaceVariableInFile slack_message_sent 0 $rc_file 
  else
    echo -e "${BLUE}Found screen inactivity${NORMAL}"
    if [[ "$first_locked" == "0" ]]; then
      # increment first locked and second locked
      replaceVariableInFile first_locked `date +%s` $rc_file &&
      replaceVariableInFile second_locked `date +%s` $rc_file
    else
      replaceVariableInFile second_locked `date +%s` $rc_file
      TIME_DIFFERENCE="$((second_locked-first_locked))"
      if [ "$TIME_DIFFERENCE" -ge "$MAX_TIME_AWAY_IN_SECS" ]; then
        if [[ "$slack_message_sent" == "0" ]] && [[ "$first_locked" != "0" ]]; then
          #TODO: send actual slack message here
          selectRandomExcuse
          finalExcuse="I will be away ${randomExcuse}"
          runIfWorkPeriod sendMessageToSlackChannel "$finalExcuse"
        fi
      fi
    fi
  fi
  cat $rc_file

}


#TODO: use getopts for these options
# number in seconds after system sleep to send message
rc_file=.examplerc
start_time="09:00"
end_time="21:00"
MAX_TIME_AWAY_IN_SECS=10
SLEEP_BETWEEN_RUNS=10
while getopts "p:s:r:e:m:h" opt   
do                
  case "$opt" in      
    p ) export rc_file="$OPTARG" ;;
    s ) export start_time="$OPTARG" ;;
    e ) export end_time="$OPTARG";;
    r ) export SLEEP_BETWEEN_RUNS="$OPTARG";;
    m ) export MAX_TIME_AWAY_IN_SECS="$OPTARG";;
    h ) helpFunction ;;                        
  esac   
done

while true
do
  main
  sleep $SLEEP_BETWEEN_RUNS
done

