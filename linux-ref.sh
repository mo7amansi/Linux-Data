## Firewalld
    {
        
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

        journalctl              # list all logs
        journalctl -n 15        # last 15 logs
        journalctl -p err       # just err logs (priority)
        
        vim /run/log/journal    # stored logs & it's not persistent (temporary)

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

