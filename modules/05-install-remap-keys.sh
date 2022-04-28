#!/usr/bin/env zsh
# vi: ft=zsh

function ensureRightAccess() {
  local filesystemItem="$1"
  chown root:wheel ${filesystemItem}
  chmod ugo=rx ${filesystemItem}
}

function createRemapKeysBinary() {
  cat > ${remapKeysPath} <<- BINARY
	#!/bin/zsh
	PRODUCT_MATCHER='{"ProductID":0x7a5,"VendorID":0x45e}'
	
	hasMappingBeenAlreadyActivated() {
	  local currentModifierKeyMappings="\`hidutil property --get UserKeyMapping -m '{"ProductID":0x7a5,"VendorID":0x45e}' | grep HIDKeyboardModifierMappingDst | wc -l\`"
	  test "\${currentModifierKeyMappings}" -gt 1
	}
	
	hasMappingBeenAlreadyActivated && exit 0
	hidutil property --matching "\${PRODUCT_MATCHER}" --set '{"UserKeyMapping": [
	    {"HIDKeyboardModifierMappingSrc": 0x700000065, "HIDKeyboardModifierMappingDst": 0x7000000e7},
	    {"HIDKeyboardModifierMappingSrc": 0x7000000e3, "HIDKeyboardModifierMappingDst": 0x7000000e2},
	    {"HIDKeyboardModifierMappingSrc": 0x7000000e2, "HIDKeyboardModifierMappingDst": 0x7000000e3}
	]}' > /dev/null 2>&1
	BINARY
  ensureRightAccess ${remapKeysPath}
}

function createXPCConsumer() {
  clang -framework Foundation -x objective-c -o ${xpcConsumerPath} - <<- BINARY
	#import <Foundation/Foundation.h>
	#include <xpc/xpc.h>
	
	int main(int argc, const char * argv[]) {
	    @autoreleasepool {
	        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
	        xpc_set_event_stream_handler("com.apple.iokit.matching", NULL, ^(xpc_object_t _Nonnull object) {
	            const char *event = xpc_dictionary_get_string(object, XPC_EVENT_KEY_NAME);
	            NSLog(@"%s", event);
	            dispatch_semaphore_signal(semaphore);
	        });
	        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
	        if(argc >= 2) {
	            execv(argv[1], (char **)argv+1);
	        }
	    }
	}
	BINARY
  ensureRightAccess ${xpcConsumerPath}
}

function createLaunchDaemon() {
  cat > ${launchDaemonPath} <<- LDAEMON
	<?xml version="1.0" encoding="UTF-8"?>
	<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
	<plist version="1.0">
	  <dict>
	    <key>Label</key>
	    <string>${serviceName}</string>
	    <key>ProgramArguments</key>
	    <array>
	        <string>${xpcConsumerPath}</string>
	        <string>${remapKeysPath}</string>
	    </array>
	    <key>LaunchEvents</key>
	    <dict>
	      <key>com.apple.iokit.matching</key>
	      <dict>
	        <key>com.apple.device-attach</key>
	        <dict>
	            <key>idProduct</key>
	            <integer>1957</integer>
	            <key>idVendor</key>
	            <integer>1118</integer>
	            <key>IOProviderClass</key>
	            <string>IOUSBDevice</string>
	            <key>IOMatchLaunchStream</key>
	            <true/>
	        </dict>
	      </dict>
	    </dict>
	  </dict>
	</plist>
	LDAEMON
  ensureRightAccess ${launchDaemonPath}
}

function enableLaunchDaemon() {
  launchctl bootstrap system ${launchDaemonPath}
}

function configure_system() {
  lop -y h1 -- -i 'Configure Microsoft Keyremapper'
  local serviceName='de.astzweig.macos.launchdaemons.keymapper'
  local dstDir='/usr/local/bin'
  local xpcConsumerPath="${dstDir}/astzweig-xpc-consumer"
  local remapKeysPath="${dstDir}/remap-keys"
  local launchDaemonPath="/Library/LaunchDaemons/${serviceName}.plist"
  ensurePathOrLogError ${dstDir} 'Could not install remap-keys.' || return 10
  [[ -x ${remapKeysPath} ]] || indicateActivity -- 'Create remap-keys executable' createRemapKeysBinary
  [[ -x ${xpcConsumerPath} ]] || createXPCConsumer 'Create XPC event consuer'
  [[ -f ${launchDaemonPath} ]] || createLaunchDaemon 'Create Launch Daemon'
  indicateActivity -- 'Enable Launch Daemon' enableLaunchDaemon
}

function getExecPrerequisites() {
  cmds=(
    [clang]=''
    [launchctl]=''
    [cp]=''
    [chown]=''
    [chmod]=''
  )
}

function getUsage() {
  read -r -d '' text <<- USAGE
	Usage:
	  $cmdName show-questions [<modkey> <modans>]...
	  $cmdName [-v] [-d FILE]
	
	Install a system wide key remapper for the Microsoft Sculpt Keyboard using
	macOS nativ hidutil, in order to swap command and option key.
	
	Options:
	  -d FILE, --logfile FILE         Print log message to logfile instead of stdout.
	  -v, --verbose                   Be more verbose.
	----
	$cmdName 0.1.0
	Copyright (C) 2022 Rezart Qelibari, Astzweig GmbH & Co. KG
	License EUPL-1.2. There is NO WARRANTY, to the extent permitted by law.
	USAGE
  print -- ${text}
}

if [[ "${ZSH_EVAL_CONTEXT}" == toplevel ]]; then
  test -f "${ASTZWEIG_MACOS_SYSTEM_LIB}" || { echo 'This module requires macos-system library. Please run again with macos-system library provieded as a path in ASTZWEIG_MACOS_SYSTEM_LIB env variable.'; return 10 }
  source "${ASTZWEIG_MACOS_SYSTEM_LIB}"
  module_main $0 "$@"
fi
