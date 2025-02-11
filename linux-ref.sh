## Storage
    {
        @fdisk

        fdisk -l /dev/sda           # list disk info.
        lsblk -pf                   # list partitions & filesystem.

        ## Create partition and make file system
            fdisk /dev/sda                              # create new partition
                # it will open terminal and go through instruction steps ^_^, assume partition name is sda1
            mkfs -t ext4 /dev/sda1                      # make file system
            mount   /dev/sda1   /data1                  # mount file system (@runtime)
            partprobe   /dev/sda1

            # for permanent
            vim /etc/fstab
                UUID    /data1      ext4    defaults    0   0               # blkid /dev/sda1 >> to know partition id
            mount -av

        ## Delete partition
            umount  /data1
            vim     /etc/fstab      # delete UUID
            fdisk   /dev/sda
                # go through instruction steps and delete partition.

        ## Create swap partition
            fdisk /dev/sda                              # create new partition
                # assume swap partition is sda3
            mkswap  /dev/sda3                           # make swap
            swapon  /dev/sda3                           # enable swapping   # we can disable it also with swapoff

            # for permanent
            vim /etc/fstab
                UUID    none      swap    defaults    0   0
            swapon -av

        ## Create swap file >> if there are no available partitions
            touch /swapfile
            dd  if=/dev/zero    of=/swapfile    bs=1024 count=1024      # adding 1G size to /swapfile file
            mkswap  /swapfile
            chmod 600 /swapfile
            swapon  /swapfile

            # for permanent
            vim /etc/fstab
                /swapfile    swap      swap    defaults    0   0
            swapon -av

        ## Take an MBR Backup
            dd  if=/dev/sda    of=/mbr-backup     bs=512  count=1
        
        ## Restore MBR Backup
            dd  if=/mbr-backup    of=/dev/sda     bs=512  count=1

        --------------------------------------

        @parted     # for partitioning & NOTE: it affected immediately!!!

        ## create partition
            parted /dev/sda                 # will open interactive session & go through instruction steps
                print                       # show disk details
                mklabel msdos               # partitioning schema: MBR > msdos && GPT > gpt
                mkpart                      # to make partition and go through instructions
                                                # start >> 0%
                                                # end   >> 25%     # partition size is 25% disk size
                
                unit % or GB or MB ...      # then print >> will show partition size with selected unit

            mkfs -t ext4 /dev/sda1
            mount /dev/sda1 /mnt/data1

            # for permanent
            vim /etc/fstab
                UUID    /mnt/data1      ext4    defaults    0   0
            mount -av

            parted /dev/sda mkpart primary ext4 25% 50%         # E.X. add partition with one command
            parted /dev/sda rm 2                                # remove partition 2

        ## resize partition
            umount /mnt/data
            parted /dev/sda 
                resizepart 1 40%

            resize2fs /dev/sda1             # if using another filesystem then >> use xfs_growfs command
            mount /dev/sda1 /mnt/data1
            systemctl daemon-reload

        --------------------------------------

        @LVM

        yum install lvm2 -y                 # install LVM package

        ## Create LVM lv1 setup using one physical device 50G and mount it to /mnt/data
            pvcreate    /dev/sdb                            # create physical volume
            vgcreate    vg_data    /dev/sdb                 # create volume group
            lvcreate    -n lv1  -L 50G  vg_data             # create logical  volume
            mkfs -t ext4 /dev/vg_data/lv1                   # format with ext4
            mount /dev/vg_data/lv1  /mnt/data

            # for permanent
            vim /etc/fstab
                UUID    /mnt/data     ext4    defaults    0   0
            mount -av

        ## Extend logical volume lv1 to 70G 'assume there are no available space on volume group vg_data'
            pvcreate    /dev/sdc                            # create second physical volume
            vgextend    vg_data     /dev/sdc                # extend volume group with second physical volume
            lvextend    -r -L +20G  /dev/vg_data/lv1        # extend logical volume

        ## Reduce logical volume lv1 to 40G (NOTE: we can't shrink XFS file system!!!)
            umount /mnt/data
            lvreduce    -r -L -30G  /dev/vg_data/lv1
            mount /dev/vg_data/lv1  /mnt/data

        ## Replace a Failed Disk /dev/sdb in Volume Group 'assume there are no available space on volume group vg_data' so we should extend volume group firstly
            pvcreate    /dev/sdd
            vgextend    vg_data     /dev/sdd
            pvmove      /dev/sdb                            # move data from failing disk /dev/sdb
            vgreduce    vg_data     /dev/sdb                # remove /dev/sdb from volume group
            pvremove    /dev/sdb                            # remove its physical group

            # NOTE: if there are enough space in volume group vg_data for data inside /dev/sdb we don't need first two steps

        ## Remove the LVM setup
            umount      /mnt/data
            vim /etc/fstab
            lvchange    -an     /dev/vg_data/lv1            # deactivate logical volume
            lvremove    /dev/vg_data/lv1
            vgremove    vg_data
            pvremove    /dev/sdc    /dev/sdd

        --------------------------------------

        @VDO    # with LVM to optimize storage by deduplicating, compressing, and managing logical volumes.

        yum install vdo kmod-kvdo -y

        ## E.X.
            pvcreate    /dev/sdb                            
            vgcreate    vg_vdo    /dev/sdb                 
            lvcreate    --type vdo -n lv_vdo  -L 50G  vg_vdo             
            mkfs -t ext4 /dev/vg_vdo/lv_vdo                  
            mount /dev/vg_vdo/lv_vdo  /data_vdo

        vdostats

        lvs -o lv_name,vdo_compression,vdo_deduplication            # check if compression and deduplication enabled or disabled
        lvchange --compression   n /dev/vg_vdo/lv_vdo               # enable/disable it (n/y)
        lvchange --deduplication n /dev/vg_vdo/lv_vdo

        --------------------------------------

        @STRATIS

        yum install stratisd stratis-cli -y
        systemctl start  stratisd
        systemctl enable stratisd

        ## create stratis pool & create filesystem
            stratis pool create pool1 /dev/sda                  # create a pool
            stratis pool list
            stratis filesystem create pool1 fs1                 # create filesystem
            stratis filesystem list
            mount    /dev/stratis/pool1/fs1     /pool1_data

            # for permanent
            vim /etc/fstab
                UUID    /pool1_data     xfs    defaults,x-systemd.requires=stratisd.service    0   0
            systemctl daemon-reload
            mount -av

        stratis pool add-data pool /dev/sdb                 # extend existing pool
        stratic filesystem snapshot pool1 fs1 snap1         # create a snapshot of filesystem
            mount /dev/stratis/pool1/snap1  /pool1_data     # mount snapshot if filesystem corrupted

        ## delete pool
            umount /pool1_data
            stratis filesystem destroy pool1 fs1            # delete filesystem
            stratis pool destroy pool1                      # delete pool
            wipefs  -a  /dev/sda                            # clean up 

    }

**************************************

## Boot
    {
        @GRUP       # >> load kernel

        /boot/grub2/grub.cfg        # main config. file >> # DO NOT EDIT THIS FILE
                                    # It is automatically generated by grub2-mkconfig
                                    
        # using templates from /etc/grub.d 
        # and settings    from /etc/default/grub

        ## E.X.  >> Update GRUB configuration (permanent changes)
            vim /etc/default/grub
            grub2-mkconfig -o /boot/grub2/grub.cfg              # BIOS systems >> IMPORTANT!!! to apply changes.
            grub2-mkconfig -o /boot/efi/EFI/redhat/grub.cfg     # UEFI systems >> IMPORTANT!!! to apply changes.

        ## reset root password!
            # 1- At the GRUB menu, edit the kernel boot line: Press e to edit the boot entry. 
            # Locate the line that starts with linux or linuxefi. Append >> rd.break << to the end of this line. then CTRL + X

            mount -o remount,rw /sysroot        # Remount the root filesystem as read-write >> to run commands.
            chroot /sysroot                     # Access the root filesystem (/).
            passwd                              # Reset root password.
            touch /.autorelabel                 # SELinux relabeling >> IMPORTANT!!!
            exit
        
        ## set grub password!   >>  we can't reset root password without this one!
            grub2-setpassword                                   # Add and confirm the password.
            grub2-mkconfig -o /boot/grub2/grub.cfg              # BIOS systems >> IMPORTANT!!! to apply changes.
            grub2-mkconfig -o /boot/efi/EFI/redhat/grub.cfg     # UEFI systems >> IMPORTANT!!! to apply changes.

            /boot/grub2/user.cfg                # password hash is stored in this location.

        ## remove grub password     >>     this method when we forgot root password and grub password also >> so will need to access with live CD
            
            # 1- use live cd (CentOS - Ubuntu) then boot from it
            # 2- mount / >> we can access partitions from file manager then will mounted automatically
            # 3- as a root remove the file:
                rm  /<mount_path>/boot/grub2/user.cfg

        --------------------------------------

        @KERNEL

        ls -l /boot/vmlinuz-*                           # compressed kernel images.
        ls /boot/loader/entries                         # kernel entries conf. files.

        ## Change Default Boot Kernel
        ### With grubby command
            grubby --default-kernel                     # listing the Default Kernel
            grubby --default-index                      # index number of the current default kernel
            grubby --info=ALL | egrep -i 'index|title'  # list of installed kernels
            grubby --set-default-index=1                # Changing default kernel Boot entry with entry-index
            reboot

        ### another one
            vim /etc/default/grub           # change GRUB_DEFAULT to the index number you need to boot from it according to the black screen that appear when starting system starting from 0 index
            update-grub                     # for ubuntu

        --------------------------------------

        @SYSTEMD_TARGETS

        systemctl get-default                       # Viewing Current Default Boot Target
        systemctl set-default graphical.target      # Change Default Boot Target, need a reboot!!!
        systemctl isolate graphical.target          # Change state and don't need a reboot >> NOTE: not working for all targets

        /etc/systemd/system/default.target          # File that contain default boot target

        --------------------------------------

        systemctl rescue            # Boot into rescue mode
        systemctl emergency         # Boot into emergency mode

    }

**************************************

## Networking
    {
        # Check Network status
            ifconfig
            ip addr
            ip route
            netstat -nr
            curl ifconfig.me        # show server public ip

        /etc/NetworkManager/system-connections      # where NetworkManager stores configuration files for network connections.

        # nmcli tool
            nmcli general permissions   # display user's permissions for managing network
            nmcli dev  show
            nmcli conn show

            # add new connection
            nmcli conn add test-con test type ethernet ifname enp0s3 ipv4.method manual ipv4.addresses 192.168.1.50 ipv4.gateway 192.168.1.1 autoconnect yes
            nmcli conn up test-con
            
            nmcli conn down   test-con
            nmcli conn delete test-conn

            # modify connection
            nmcli conn modify test-con +ipv4.addresses 192.168.1.90     # + sign to add second property e.x. second ip
            or

            cd /etc/NetworkManager/system-connections        # vim conn file for test-con and edit it
            nmcli con reload test-con                        # if it isn't affected then do >> nmcli con down test-con & nmcli con up test-con

        # Network Troubleshooting
            ifconfig -a                 # check physical connection same as >> ip a
            ethtool  [interface]
            mii-tool [interface]
                # o/p should be link ok.

            ip route                    # shows routes and default gateway same as >> route -n
                route add default gw 192.168.1.1        # if default gw not exist

            ping       google.com       # check if server is reachable, if not try also 8.8.8.8
            traceroute google.com       # check the path that data takes and where problems might be occurring
            nslookup   google.com       # check if DNS resolved to ip correctly or not
            dig        ggole.com        # for DNS more details

            vim /etc/resolve.conf
                - nameserver 8.8.8.8

            vim /etc/nsswitch.conf      # we found hosts: files  dns  myhostname
                # files >> /etc/hosts , dns >> /etc/resolve.conf
                # it means when doing ping command it check with this order and we can change it.
        
        netstat -ltpn   # show ports where services are listen

        **************************************

        ## How to configure Network Bonding  >>  combine physical and virtual network interfaces to provide a logical interface.
        # 1- create bond connection
        nmcli conn add type bond con-name bond0 ifname bond0 mode active-backup

        #2- add slaves NICs to Bond at least 2 NICs
        nmcli conn add type ethernet port-type bond con-name bond0-port1 ifname enp0s3 controller bond0
        nmcli conn add type ethernet port-type bond con-name bond0-port2 ifname enp0s8 controller bond0
        or

        nmcli conn modify bridge0 controller bond0  # if there are profiles for slaves
        nmcli conn modify bridge1 controller bond0

        #3- reactive connections
        nmcli conn up bridge0
        nmcli conn up bridge1

        #4- assign ip for bond
        nmcli conn modify bond0 ipv4.method manual ipv4.addresses 192.0.2.1/24  ipv4.gateway 192.0.2.254

        nmcli conn up bond0

    }

**************************************

## Yum
    {
        yum search  httpd
        yum install httpd
        yum update  httpd
        yum remove  httpd
        yum list installed
        yum check-update                # list packages that have available updates
        yum localinstall [/path.rpm]    # install RPM package file located in local machine

        /etc/yum.conf                   # main configuration file
        /etc/yum.repos.d                # this directory contain all local repos that yum search from it and we can open any one and edit on it maybe we can disable someone ^_^

        ## How to declare new repo?
            1- vim /etc/yum.repos.d/myrepo.repo
                [myrepo]
                name=My Repository
                baseurl=http://example.com/repo                              # baseurl is the location of the repository's files. E.X. HTTP/HTTPS: http://example.com/repo/ or  FTP: ftp://repo.example.com/repo/   or  Local Path: file:///mnt/myrepo/
                enabled=1
                gpgcheck=1
                gpgkey=http://<server_IP_or_URL>/path_to_repo/RPM-GPG-KEY    # we can miss this one if we don't need to check package verification
            
            2- yum clean all            # To ensure YUM fetches fresh metadata and packages from repositories.
            3- yum repolist

        yum-config-manager --add-repo "http://example.com/repo"   # simple way to add new repo without manually editing .repo files.
        yum-config-manager --enable/disable [repo_id]             # enable or disable repo. & i can get repo id from >> yum repolist

        ## manage group of packages
            yum grouplist
            yum groupinstall "group_name"
            yum groupremove  "group_name"

        yum history             # view the history of installed, removed, or updated packages.
        yum history undo [id]   # undo a specific transaction.
    
    }

**************************************

## Scheduling
    {
        @crond      # for repeated tasks

        crontab -l          # list cron scheduled
        crontab -r          # remove current cron
        crontab -e          # create or modify cron
        crontab -e -u user  # create or modify cron for another user

        # E.X.  
        crontab -e
              *      *           *            *          *      /script  or  command
            minute  hour    day-in-month    month   day-in-weak
            (0-59) (0-23)      (1-31)       (1-12)     (0-7)        # 0,7 == sunday

            *       *   *   *   *   # every minute
            0       *   *   *   *   # every hour
            */10    *   *   *   *   # every 10 minute
            0       17  *   *   0   # every sunday @ 5 p.m.

            @yearly @monthly ...    # start of year, month,...
            @reboot                 # every reboot

        vim /etc/cron.deny          # to deny user for using scheduling
        vim /etc/cron.allow         # to allow only these users using scheduling

        vim /etc/cron.daily         # run tasks daily
        vim /etc/cron.weekly        # run tasks weekly
        .
        .
        --------------------------------------

        @atd      # run tasks one time

        at -l           # list jobs
        at -r [job_id]  # remove job

        ## How to create job?

        1- using at prompt
            at +time         # time = 23:17, noon, 6AM, noon + 4 days,...
                # will open terminal >> write the command then "CTRL+d"
        
        2- using pipe
            echo "date > /home/mansi/test" | at now

        at -c [job_id]       # job scripts == /var/spool/at

    }

**************************************

## Logs
    {
        @rsyslog    # read logs from journald and storing under /var/log

        vim /etc/rsyslog.conf                       # main config. file
        logger "Hello, this is a test message"      # testing rsyslog

        tail -f /var/log/syslog       # For Debian/Ubuntu
        tail -f /var/log/messages     # For CentOS/RHEL

        ## Central Logging Server Demo
            @Central_Server

            1- vim /etc/rsyslog.conf        # uncomment tcp or udp
            2- systemctl restart rsyslog.service
            3- firewall-cmd --add-service=syslog --permanent
            4- firewall-cmd --reload

            --------------------------------------

            @Clients

            1- vim /etc/rsyslog.conf        # uncomment tcp or udp and also at the end of file...
                *.*         @CENTRAL_IP
                *.err       @192.168.1.10
                *.critical  @192.168.1.10
                corn.*      @192.168.1.10
                mail.*      @192.168.1.10
                mail.err    @192.168.1.10

            2- systemctl restart rsyslog.service
            3- logger -i "this is a test message from client1"

        --------------------------------------

        ##Logrotate

        vim /etc/logrotate.conf                       # main config. file
        
        **************************************
        
        @Journald

        journalctl                      # list all logs
        journalctl -u NetworkManager    # list NetworkManager logs
        journalctl -n 15                # last 15 logs
        journalctl -p err               # just err logs (priority)
        
        vim /run/log/journal            # stored logs & it's not persistent (temporary)

        ## How to make journald logs persistent

        1- mkdir /var/log/journal
        2- chown -R root:systemd-journal /var/log/journal
        3- chmod g+s /var/log/journal
        4- vim /etc/systemd/journald.conf
            storage=persistent
        5- systemctl restart systemd-journald.service
        
    }

**************************************

## ACL
    {
        getfacl file1                       # check ACL for file1
        setfacl -m "u:mansi:rwx" file1      # add permission for user mansi
        setfacl -m "g:prod:-"     file1     # add permission for a group prod

        #Changing group permissions on a file with an ACL by using chmod does not change the group owner permissions, but does change the ACL mask.
        #The ACL mask defines the maximum permissions that you can grant to named users, the group owner, and named groups.
        setfacl -m "g::r" file1
        setfacl -m -n "u:mansi:rw" file1    # To avoid mask recalculation

        ## Default ACL
        setfacl -dm "u:mansi:rwx" dir1      # To allow all files or directories to inherit ACL entries from dir1
        setfacl -Rm "u:mansi:rwx" dir1      # To allow all old files or old directories to inherit ACL entries from dir1

        ## Removing ACLs
        setfacl -x "u:mansi" file1          # remove specific entry
        setfacl -b file1                    # remove all ACLs entry

        ## Backup & Copying ACL
        getfacl file1 > acl.txt
        setfacl --set-file=acl.txt file2

        getfacl file1 | setfacl --set-file=- file2      # copying the ACL of one file to another but with one command ^_^
        getfacl file1 | setfacl -d -M- file2            # copying the access ACL into the Default ACL

    }

**************************************

## Firewalld
    {
        yum install firewalld
        systemctl start firewalld

        #adding http to firewall
        ##note any command will be applied to default zone -public-,
        ##if we need to apply commands to different zones will added --zone=public to command.

        firewall-cmd --add-port=80/tcp
        firewall-cmd --add-service=http --permanent
        firewall-cmd --reload               #to apply changes after --permanent
        firewall-cmd --list-all

        vim /usr/lib/firewalld/services     #each XML file in this directory correspond to service have details like (port, protocols,...)
        vim /usr/lib/firewalld/zones 

        ##rich rules
        #accept traffic from specific source 
        firewall-cmd --zone=public --add-rich-rule='rule-family="ipv4" source address="192.168.1.10/24" service name="http" accept'
        #drop traffic from specific source 
        firewall-cmd --zone=public --add-rich-rule='rule-family="ipv4" source address="192.168.1.10/24" service name="http" drop'

    }

**************************************

## SELinux
    {
        sestatus    #ESLinux status have 3 modes (enforcing, permissive, disabled)
        setenforce 1    #enforcing  @ runtime
        setenforce 0    #permissive @ runtime
        vim /etc/selinux/config     #config. file (for permanent)

        ls -lZ      #List context
        ps -Z       #List precesses context
        vim /etc/selinux/targeted/contexts/files/file_contexts      #Contexts naming (DB)
        
        chcon -t "httpd_sys_content_t" /mnt/website     #changing context @ runtime
        restorecon -v /mnt/website                      #restore default context based on Contexts naming (DB)


        semanage fcontext -a -t "httpd_sys_content_t" '/mnt/website(/.*)?'      #changing context (permanent)
        restorecon -vR /mnt/website                     #Ensures the new context is applied

        semanage port -a -t "http_port_t" -p tcp 82     
        semanage -lC        #show modification that are changed

        #To override an existing port that was already created, use the -m option
        semanage port -m -t "http_port_t" -p tcp 2222

        semanage permissive -a httpd_t              #SELinux will be permissive for apache only
        semanage permissive -d httpd_t              #To delete it again 
        semanage permissive -l

        --------------------------------------

        @SELinux_Booleans

        semanage booleans -l                        #List SELinux booleans
        setsebool -P  <boolean>   on/off            #Enable or disable a SELinux boolean. (permanent)

        --------------------------------------

        ausearch -m AVC -ts recent                  #search inside audit.log
        sealert  -a /var/log/audit/audit.log        #search inside audit.log as a report form

        
    }

**************************************

## NFS 
    {
        @SERVER

        yum install nfs-utils -y
        systemctl enable    nfs-server.service
        systemctl start     nfs-server.service

        firewall-cmd --add-service=nfs      --permanent
        firewall-cmd --add-service=rpc-bind --permanent
        firewall-cmd --add-service=mountd   --permanent
        firewall-cmd --reload

        #edit export file > assume that we have /data directory we need to share it
        vim /etc/exports
            /data       *(rw)                   #anyone
            /data       192.168.1.10(rw)        #host
            /data       *.cloud.com(rw)         #domain

        #reread configuration files refresh
        exportfs -r

        --------------------------------------

        @CLIENT

        yum install nfs-utils

        showmount -e $SERVER_IP         # to know the shared directories

        mkdir /test-point               # for mount point

        #on runtime method
        mount -t nfs4   $SERVER_IP:/data    /test-data   

        #for permanent
        vim /etc/fstab
            $SERVER_IP:/data    /test-data      nfs4    defaults    0   0
        mount-a

        df -h 

        **************************************

        ##autofs (automounter) >> @Client-Side configuration only

        @DIRECT_MAP

        yum install autofs

        #create master-map file
        vim /etc/auto.master.d/direct.autofs
            /-          /etc/demo.direct        # (All direct map entries use /- as the base directory.)

        #create mapping file
        mkdir /test-direct
        vim /etc/demo.direct
            /test-direct/data   -rw,sync    $SERVER_IP:/data    #The full directory /test-direct/data will be created and removed automatically by the autofs service

        systemctl restart autofs.service

        --------------------------------------

        @INDIRECT_MAP

        yum install autofs

        #create master-map file
        vim /etc/auto.master.d/indirect.autofs
            /test-indirect      /etc/demo.indirect      #(/test-indirect directory as the base for indirect automounts, and will created automatically)

        #create mapping file
        vim /etc/demo.indirect
            *      -rw,sync    $SERVER_IP:/data/&          

        systemctl restart autofs.service
    }

**************************************

## Samba
    {
        @SERVER

        yum install samba samba-client samba-common -y
        systemctl enable smb nmb
        systemctl start  smb nmb

        firewall-cmd --add-service=samba      --permanent
        firewall-cmd --reload

        mkdir /samba_share
        chown nobody:nobody /samba_share        # if needed.

        vim /etc/samba/smb.conf                 # edit config. for shared directory
            [samba_share]
            comment = this is a comment
            path = /samba_share
            browseable = yes
            public = yes
            read only = yes
            guest ok = yes
            # valid users = samba_user
            # valid users = @group1
            # hosts allow = 192.168.1.0/24
            # hosts deny  = 10.20.30.0/24

        testparm                                # check config. file syntax
        systemctl restart smb

        semanage fcontext -a -t samba_share_t "/samba_share(/.*)?"      # change context for shared directory >> IMPORTANT!!!
        restorecon -R /samba_share
        setsebool  -P samba_enable_home_dirs on                         # Allows Samba to share users' home directories.
        setsebool  -P samba_export_all_rw    on                         # Allows Samba to share all files with read-write perm.

        useradd   -s /sbin/nologin samba_user                           # create user without shell.
        smbpasswd -a samba_user                                         # set password for samba_user to access samba server from client.
        smbpasswd -e samba_user                                         # enable samba_user
        systemctl restart smb

        --------------------------------------

        @CLIENT

        ## linux client
            yum install samba-client cifs-utils -y      # CIFS is used by Linux clients to mount and access Samba shares on a Samba server.
            smbclient -L //$SERVER_IP                   # list shared dirs. from samba server >> don't enter password.
            
            mkdir -p /samba_data
            mount -t cifs //$SERVER_IP/samba_share /samba_data -o username=samba_user

            #for permanent
            vim /etc/fstab
                //$SERVER_IP/samba_share    /samba_data      cifs    username=samba_user,password=123,defaults    0   0
            mount -a

        ## windows client
            # 1- press WINDOWS + R
            # 2- type   \\$SERVER_IP\samba_share
            # 3- type   samba_user & password

    }

**************************************

## FTP
    {
        @SERVER

        yum install vsftpd -y
        systemctl enable vsftpd
        systemctl start  vsftpd

        firewall-cmd --add-service=ftp --permanent
        firewall-cmd --reload

        cp  /etc/vsftpd/vsftpd.conf  /etc/vsftpd/vsftpd.conf.backup   # create a backup first
        vim /etc/vsftpd/vsftpd.conf
            
            anonymous_enable=NO                 # Prevents anonymous users from logging in to FTP server
            local_enable=YES                    # allow local users
            write_enable=YES                    # allow logged-in user to upload files to FTP server
            
            # by default local users can change there directory >> IMPORTANT!!!
            chroot_local_user=YES               # restrict access to everything except the home directory
                chroot_list_enable=YES          # If set to YES, you can specify a list of users who will be excluded from chrooting (if chroot_local_user=YES) or included in chrooting (if chroot_local_user=NO).
                chroot_list_file=/etc/vsftpd/chroot_list        # contains the list of users to be included or excluded from chrooting, depending on the chroot_local_user setting.
                allow_writeable_chroot=YES      # to work correctly if user home directory have write perm.

            # passive mode >> provides client with a range of ports it can use to establish the data connection. (required when FTP server is behind a firewall or NAT).            
            pasv_enable=YES
            pasv_address=$SERVER_IP
            pasv_min_port=10000
            pasv_max_port=10100
            firewall-cmd --add-port=10000-10100/tcp --permanent
            firewall-cmd --reload
            
            # This create an approved user list only 
            userlist_enable=YES
            userlist_file=/etc/vsftpd/user_list
            userlist_deny=NO                    # if this YES >> would change the list to blocked users.

        setsebool -P ftpd_full_access on
        sudo systemctl restart vsftpd

        --------------------------------------

        @CLIENT

        yum install ftp -y
        ftp $SERVER_IP              # then login with username and password
            passive                 # write passive to enter passive mode

    }

**************************************

## DHCP
    {
        @SERVER

        yum install dhcp-server -y
        systemctl enable dhcpd
        systemctl start  dhcpd

        firewall-cmd --add-service=dhcp --permanent
        firewall-cmd --reload

        ## NOTE >> maybe service status is enabled but failed.

        vim /etc/dhcp/dhcpd.conf                             # didn't found anything >> so look at the Examples boooy!
        vim /usr/share/doc/dhcp-server/dhcpd.conf.example    # example with all details ^_^
        
        vim /etc/dhcp/dhcpd.conf
            # IMPORTANT!!! >>> this is a global will apply to all subnets. >> default values if not specified in subnet.
            option domain-name "server.com";
            option domain-name-servers 208.67.222.222, 208.67.220.220, ns1.mansi.com;

            default-lease-time 7200;
            max-lease-time 10800;

            authoritative;          # If this DHCP server is the official DHCP server

            # Use this to send dhcp log messages to a different log file (you also
            # have to hack syslog.conf to complete the redirection).
            log-facility local7;

            # configuration for an internal subnet only.
            subnet 192.168.1.0 netmask 255.255.255.0 {
                range  192.168.1.150 192.168.1.250;
                option domain-name-servers 8.8.8.8;
                option routers 192.168.1.1;                 # Default Gateway
                option broadcast-address 192.168.1.255;
                default-lease-time 600;                     # 
                max-lease-time 7200;
            }

        @CLIENT

        yum install dhcp-client -y
        cat /var/lib/dhclient/dhclient.leases               # show details about lease history. 

        dhclient            # request new ip from dhcp
        dhclient -r         # remove current ip & notify dhcp server that ip is free
        dhclient -v         # renew current IP (verbose mode)

        # (Deletes old leases and forces a fresh IP request.)
            rm -f /var/lib/dhclient/dhclient.leases
            dhclient -v

    }

**************************************

## DNS
    {
        @BIND

        @SERVER

        yum install bind bind-chroot bind-utils -y                  # bind > dns implementation, bind-chroot > (jailed) environment, which isolates it from the rest of the system, bind-utils > DNS client tools for testing and troubleshooting.
        firewall-cmd --add-service=dns --permanent
        firewall-cmd --reload

        # if DNS not in jailed environment
        cat /var/named/named.ca             # contain records for 13 root servers
        cat /etc/named.conf                 # main bind config file
        ls /var/named/                      # for data files

        # to enable jail environment        >>      / == /var/named/chroot
        systemctl disable named                         
        systemctl stop named
        systemctl mask named

        cd /var/named/chroot
        cp -r /usr/share/doc/bind/sample/etc/ .                     # copy config. files to chroot directory
        cp -r /usr/share/doc/bind/sample/var/ .                     # copy data. files to chroot directory
        chown named:named -R /var/named/chroot/var/named/
        systemctl restart named-chroot

        vim /etc/named.conf
                #    listen-on port 53 { 127.0.0.1; 192.168.1.146; };
                #    allow-query       { localhost; 192.168.1.0/24; };

        named-checkconf                 # check config. file syntax
        systemctl restart named-chroot

        ## IMPORTANT!!! >> service files should be owned by "named" service user
            cd /var/named/chroot
            chown root:named  -R /etc/
            chown root:named  -R /var/
            restorecon -Rv /var/named/chroot

        @CLIENT

        nmcli connection modify enp0s3 ipv4.dns $SERVER_IP          # edit dns with dns local server ip
        nmcli connection down enp0s3
        nmcli connection up   enp0s3
        
        @SERVER 
        
        tcpdump udp dst port 53         # configure client server then test if client server use this local dns server ^_^
        
        --------------------------------------

        ## Logging >> storing dns query logs

            rndc querylog                   # enable or disable query logging in BIND >> to /var/log/messages (TEMPORARY!!!)
                                            # just for testing only
            # for permanent
                vim /etc/named.conf
                    
                    logging {
                            channel default_debug {
                                    file "data/named.run";
                                    severity dynamic;
                            };
                            channel queries_channel {
                                    file "data/queries.log" versions 5 size 5M;
                                    print-time yes;
                                    print-category yes;
                                    severity dynamic;
                            };
                            channel errors_channel {
                                    file "data/errors.log";
                                    print-time yes;
                                    print-category yes;
                                    severity dynamic;
                            };
                            category queries { queries_channel; };          # "queries" for all logs
                            category default { errors_channel; };           # "default" for error logs, "network" for network logs, ...
                    };

                systemctl restart named-chroot
                # check logs under /var/named/chroot/var/named/data

        ## NOTE: with main configuration file use INCLUDE statement as much as you can.
        #        so we can write logging statement in separate file then include it in main configuration file /etc/named.conf

        --------------------------------------
        
        ## Zones

        # E.X.  >>  define forward lookup and reverse lookup zones for "mansi.com" & subnet >> 192.168.1.0/24
            # forward lookup >> translate domain name into ip
                zone "mansi.com" IN {
                    type master;
                    file "/var/named/mansi.com.forward";
                    allow_query { 192.168.1.0/24; };
                };

            # reverse lookup >> translate ip into domain name
                zone "0.168.192.in-addr.arpa" IN {
                    type master;
                    file "/var/named/mansi.com.reverse";
                    allow_query { 192.168.1.0/24; };
                };


        # Assign records to previous forward E.X.
            cd /var/named/chroot/var/named                  # as we use named-chroot
            cp named.localhost  mansi.com.forward           # copy config. example with forward file name then edit it according to your needs
            vim mansi.com.forward
                
                $TTL 1D                                                         # cache time value is 1 day
                @       IN SOA  ns0.mansi.com. admin.mansi.com. (               # define domain with started @ line, take care of dots (.)
                                                        0       ; serial
                                                        1D      ; refresh
                                                        1H      ; retry
                                                        1W      ; expire
                                                        3H )    ; minimum
                        NS      ns0.mansi.com.                                  # define nameserver
                ns0     A       192.168.1.146

                ## Note: we define nameserver with two steps. IMPORTANT!!! like mail server also.

        named-checkzone mansi.com /var/named/mansi.com.forward          # check zone configuration
        dig @192.168.1.146 ns0.mansi.com                                # should work also ^_^


    }

**************************************

## Chronyd (NTP)
    {
        https://www.youtube.com/watch?v=dUK1CfjuNfA
        https://www.youtube.com/watch?v=XjBcnpKgMJg
        https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/automating_system_administration_by_using_rhel_system_roles/configuring-time-synchronization-by-using-the-timesync-rhel-system-role_automating-system-administration-by-using-rhel-system-roles#configuring-time-synchronization-by-using-the-timesync-rhel-system-role_automating-system-administration-by-using-rhel-system-roles
    }

**************************************
