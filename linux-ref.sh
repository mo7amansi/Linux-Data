## Firewalld
    {
        
    }

**************************************

## Networking
    {
        # Check Network status
            ifconfig
            ip addr
            ip route
            netstat -nr

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
            ifconfig -a                 # check physical connection
            ethtool  [interface]
            mii-tool [interface]
                # o/p should be link ok.

            route -n                    # show route table and should specify default gateway
                route add default gw 192.168.1.1        # if default gw not exist

            try ping google.com         # should response if not do next step
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

        yum install nfs-utils
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

        showmount -e $SERVER_IP                 #to know the shared directories

        ## assume we create a directory /test-data for mount point

        #on runtime method
        mount -t nfs4   $SERVER_IP:/data    /test-data  >>  

        #for permanent
        vim /etc/fstab
            $SERVER_IP:/data    /test-data      nfs4    defaults    0   0

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

