#!/bin/bash
 
# This scripts loops through all the user's VirtualBox vm's, pauses them,
# exports them and then restores the original state.
#
# =============== Set your variables here ===============
 
  EXPORTDIR=/var/vmbackup
  MYMAIL=your@email.address
  VBOXMANAGE="/usr/bin/VBoxManage -q"
 
# =======================================================
 
# Generate a list of all vm's; use sed to remove the double quotes.
 
# Note: better not use quotes or spaces in your vm name. If you do,
# consider using the vms' ids instead of friendly names:
# for VMNAME in $(vboxmanage list vms | cud -t " " -f 2)
# Then you'd get the ids in your mail so you'd have to use vboxmanage 
# showvminfo $id or something to retrieve the vm's name. I never use
# weird characters in my vm names anyway.
 
for VMNAME in $(vboxmanage list vms | cut -d " " -f 1 | sed -e 's/^"//'  -e 's/"$//')
do
 
  ERR="nothing"
  SECONDS=0
 
  # Delete old export.log file if it exists
    if [ -e export.log ]; then rm export.log; fi
 
  # Get the vm state
    VMSTATE=$(vboxmanage showvminfo $VMNAME --machinereadable | grep "VMState=" | cut -f 2 -d "=")
    echo "$VMNAME's state is: $VMSTATE."
 
  # If the VM's state is running or paused, save its state
    if [[ $VMSTATE == \"running\" || $VMSTATE == \"paused\" ]]; then
      echo "Saving state..."
      vboxmanage controlvm $VMNAME savestate
      if [ $? -ne 0 ]; then ERR="saving the state"; fi
    fi
 
  # Export the vm as appliance
    if [ "$ERR" == "nothing" ]; then
      echo "Exporting the VM..."
      vboxmanage export $VMNAME --output $EXPORTDIR/$VMNAME-new.ova &> export.log
      if [ $? -ne 0 ]; then
        ERR="exporting"
      else
        # Remove old backup and rename new one
       if [ -e $EXPORTDIR/$VMNAME.ova ]; then rm $EXPORTDIR/$VMNAME.ova; fi
       mv $EXPORTDIR/$VMNAME-new.ova $EXPORTDIR/$VMNAME.ova
       # Get file size
       FILESIZE=$(du -h $EXPORTDIR/$VMNAME.ova | cut -f 1)
      fi
    else
      echo "Not exporting because the VM's state couldn't be saved." &> export.log
    fi
 
  # Resume the VM to its previous state if that state was paused or running
    if [[ $VMSTATE == \"running\" || $VMSTATE == \"paused\" ]]; then
        echo "Resuming previous state..."
        vboxmanage startvm $VMNAME --type headless
        if [ $? -ne 0 ]; then ERR="resuming"; fi
        if [ $VMSTATE == \"paused\" ]; then
          vboxmanage controlvm $VMNAME pause
          if [ $? -ne 0 ]; then ERR="pausing"; fi
        fi
      fi
 
  # Calculate duration
    duration=$SECONDS
    duration="Operation took $(($duration / 60)) minutes, $(($duration % 60)) seconds."
 
  # Notify the admin
    if [ "$ERR" == "nothing" ]; then
      MAILBODY="Virtual Machine $VMNAME was exported succesfully!"
      MAILBODY="$MAILBODY"$'\n'"$duration"
      MAILBODY="$MAILBODY"$'\n'"Export filesize: $FILESIZE"
      MAILSUBJECT="VM $VMNAME succesfully backed up"
    else
      MAILBODY="There was an error $ERR VM $VMNAME."
      if [ "$ERR" == "exporting" ]; then
        MAILBODY=$(echo $MAILBODY && cat export.log)
      fi
      MAILSUBJECT="Error exporting VM $VMNAME"
    fi
 
  # Send the mail
    echo "$MAILBODY" | mail -s "$MAILSUBJECT" $MYMAIL
 
  # Clean up
    if [ -e export.log ]; then rm export.log; fi
 
done