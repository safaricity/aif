#!/bin/bash

TMP_MKINITCPIO_LOG=$LOG_DIR/mkinitcpio.log
TMP_PACMAN_LOG=$LOG_DIR/pacman.log

# run_mkinitcpio() taken from setup. adapted a lot
# runs mkinitcpio on the target system, displays output
run_mkinitcpio()  
{
	target_special_fs on

	run_controlled mkinitcpio "chroot $var_TARGET_DIR /sbin/mkinitcpio -p kernel26" $TMP_MKINITCPIO_LOG "Rebuilding initcpio images ..."

	target_special_fs off

	# alert the user to fatal errors
	[ $mkinitcpio_exitcode -ne 0 ] && show_warning "MKINITCPIO FAILED - SYSTEM MAY NOT BOOT" "$TMP_MKINITCPIO_LOG" text
	return $mkinitcpio_exitcode
}


# installpkg(). taken from setup. modified bigtime
# performs package installation to the target system
installpkg() {
	ALL_PACKAGES=$var_TARGET_PACKAGES
	[ -n "$TARGET_GROUPS" ] && ALL_PACKAGES="$ALL_PACKAGES "`list_packages group "$TARGET_GROUPS" | awk '{print $2}'`
	ALL_PACKAGES=`echo $ALL_PACKAGES`
	[ -z "$ALL_PACKAGES" ] && die_error "No packages/groups specified to install"

	target_special_fs on

	notify "Package installation will begin now.  You can watch the output in the progress window. Please be patient."

	#TODO: There may be something wrong here. See http://projects.archlinux.org/?p=installer.git;a=commitdiff;h=f504e9ecfb9ecf1952bd8dcce7efe941e74db946 ASKDEV (Simo)
	run_controlled pacman_installpkg "$PACMAN_TARGET --noconfirm -S $ALL_PACKAGES" $TMP_PACMAN_LOG "Installing... Please Wait" 

	local _result=''
	if [ ${pacman_installpkg_exitcode} -ne 0 ]; then
		_result="Installation Failed (see errors below)"
		echo -e "\nPackage Installation FAILED." >>$TMP_PACMAN_LOG
	else
		_result="Installation Complete"
		echo -e "\nPackage Installation Complete." >>$TMP_PACMAN_LOG
	fi

	show_warning "$_result" "$TMP_PACMAN_LOG" text || return 1

	target_special_fs off
	sync

	return ${pacman_installpkg_exitcode}
}


# auto_locale(). taken from setup
# enable glibc locales from rc.conf and build initial locale DB
target_configure_initial_locale() 
{
    for i in $(grep "^LOCALE" ${var_TARGET_DIR}/etc/rc.conf | sed -e 's/.*="//g' -e's/\..*//g'); do
        sed -i -e "s/^#$i/$i/g" ${var_TARGET_DIR}/etc/locale.gen
    done
    target_locale-gen
}


target_locale-gen ()
{
	infofy "Generating glibc base locales..."
	chroot ${var_TARGET_DIR} locale-gen >/dev/null
}