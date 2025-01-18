## Firewalld
    {

    }

**************************************

## SELinux
    {
        
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

