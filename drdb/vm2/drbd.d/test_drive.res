resource test_drive {
        startup {
                wfc-timeout  15;
                degr-wfc-timeout 60;
                become-primary-on cluster-node1;
        }
        net {
                protocol C;
                cram-hmac-alg sha1;
                shared-secret "heslo";
        }
        on cluster-node1 {
                device /dev/drbd0;
                disk /dev/mapper/ubuntu--vg-drbd;
                address 172.16.50.110:7789;
                meta-disk internal;
        }
        on cluster-node2 {
                device /dev/drbd0;
                disk /dev/mapper/ubuntu--vg-drbd;
                address 172.16.50.111:7789;
                meta-disk internal;
        }
}
