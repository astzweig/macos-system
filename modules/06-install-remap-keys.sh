#!/usr/bin/env zsh
# vi: set ft=zsh tw=80 ts=2

function ensureRightAccess() {
	local filesystemItem="$1"
	chown root:wheel ${filesystemItem}
	chmod ugo=rx ${filesystemItem}
}

function getDataForMicrosoftKeyboard() {
	local name="$1"
	[ "$name" = "ProductID" ] && echo '0x7a5'
	[ "$name" = "VendorID" ] && echo '0x45e'
	[ "$name" = "LaunchdServiceName" ] && echo 'de.astzweig.macos.launchdaemons.microsoft-keymapper'
	[ "$name" = "BinaryName" ] && echo 'remap-keys-microsoft'
	[ "$name" = "KeyMappings" ] && cat <<- KEYMAPPINGS
		{"HIDKeyboardModifierMappingSrc": 0x700000065, "HIDKeyboardModifierMappingDst": 0x7000000e7},
		{"HIDKeyboardModifierMappingSrc": 0x7000000e3, "HIDKeyboardModifierMappingDst": 0x7000000e2},
		{"HIDKeyboardModifierMappingSrc": 0x7000000e2, "HIDKeyboardModifierMappingDst": 0x7000000e3}
	KEYMAPPINGS
}

function getDataForLogitechKeyboard() {
	local name="$1"
	[ "$name" = "ProductID" ] && echo '0xc52b'
	[ "$name" = "VendorID" ] && echo '0x46d'
	[ "$name" = "LaunchdServiceName" ] && echo 'de.astzweig.macos.launchdaemons.logitech-keymapper'
	[ "$name" = "BinaryName" ] && echo 'remap-keys-logitech'
	[ "$name" = "KeyMappings" ] && cat <<- KEYMAPPINGS
		{"HIDKeyboardModifierMappingSrc": 0x7000000e6, "HIDKeyboardModifierMappingDst": 0x7000000e7},
		{"HIDKeyboardModifierMappingSrc": 0x7000000e7, "HIDKeyboardModifierMappingDst": 0x7000000e6}
	KEYMAPPINGS
}

function createXPCConsumer() {
	[[ -x ${xpcConsumerPath} ]] && return
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

function getProductPlistDict() {
	cat <<- PLISTDICT
	<dict>
		<key>idProduct</key>
		<integer>$(($($dataProvider ProductID)))</integer>
		<key>idVendor</key>
		<integer>$(($($dataProvider VendorID)))</integer>
		<key>IOProviderClass</key>
		<string>IOUSBDevice</string>
		<key>IOMatchLaunchStream</key>
		<true/>
	</dict>
	PLISTDICT
}

function createRemapKeysBinary() {
	cat > ${binaryPath} <<- BINARY
	#!/bin/zsh
	PRODUCT_MATCHER='{"ProductID":$($dataProvider ProductID),"VendorID":$($dataProvider VendorID)}'

	hasMappingBeenAlreadyActivated() {
		local currentModifierKeyMappings="\`hidutil property --get UserKeyMapping -m "\${PRODUCT_MATCHER}" | grep HIDKeyboardModifierMappingDst | wc -l\`"
		test "\${currentModifierKeyMappings}" -gt 1
	}

	hasMappingBeenAlreadyActivated || \
	hidutil property --matching "\${PRODUCT_MATCHER}" --set '{"UserKeyMapping": [
			$($dataProvider KeyMappings)
	]}' > /dev/null 2>&1
	BINARY
	ensureRightAccess ${binaryPath}
}

function createLaunchDaemon() {
	cat > ${launchDaemonPath} <<- LDAEMON
	<?xml version="1.0" encoding="UTF-8"?>
	<!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
	<plist version="1.0">
		<dict>
			<key>Label</key>
			<string>$($dataProvider LaunchdServiceName)</string>
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
						$(getProductPlistDict)
				</dict>
			</dict>
		</dict>
	</plist>
	LDAEMON
	ensureRightAccess ${launchDaemonPath}
}

function enableLaunchDaemon() {
	launchctl enable system/${launchDaemonPath%.*}
	launchctl bootstrap system ${launchDaemonPath}
}

function createLaunchdService() {
	local launchDaemonPath="/Library/LaunchDaemons/$($dataProvider LaunchdServiceName).plist"
	[[ -f ${launchDaemonPath} ]] || indicateActivity -- 'Create Launch Daemon' createLaunchDaemon
	indicateActivity -- 'Enable Launch Daemon' enableLaunchDaemon
}

function configureKeymappers() {
	local mapper= dataProvider= binaryPath=
	for mapper dataProvider in ${(kv)mappers}; do
		lop -y h1 -- -i "Configure ${mapper} Keymapper"
		binaryPath="${dstDir}/$($dataProvider BinaryName)"
		createRemapKeysBinary
		createLaunchdService
	done
}

function configure_system() {
	typeset -A mappers=(
		[Microsoft]=getDataForMicrosoftKeyboard
		[Logitech]=getDataForLogitechKeyboard
	)
	local dstDir='/usr/local/bin'
	local xpcConsumerPath="${dstDir}/astzweig-xpc-consumer"

	ensurePathOrLogError ${dstDir} 'Could not create destination dir for remap-keys binary.' || return 10
	indicateActivity -- 'Create XPC event consumer' createXPCConsumer
	configureKeymappers
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
	  -d FILE, --logfile FILE  Print log message to logfile instead of stdout.
	  -v, --verbose            Be more verbose.
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
