## Firewalld
    {
        
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
        semanage port -m -t unreserved_port_t -p tcp 2222

        semanage permissive -a httpd_t                  #SELinux will be permissive for apache only
        semanage permissive -d httpd_t                  #To delete it again 
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

