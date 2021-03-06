#!/usr/sbin/dtrace -qs

/* 
 * This script monitors calls into sbd_zvol_unmap() and calculates the resulting 
 * time taken to perform the "delete" operation resulting from the dbuf_free_range()
 * call that is subsequently made.
 * This can be a problem in COMSTAR with Initiators performing frequent unmap/trim
 * operations as the resulting deletes can take 10's of seconds, during which time
 * other operations block.
 * This will improve once asynchronous delete code is ported, however for the time
 * being you are advised to:
 *
 * 1) Disable UNMAP/TRIM on all Initiator/Hyper-V nodes (will require a reboot):
 * 
 * HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\FileSystem\DisableDeleteNotification = 1
 *
 * 2) Review the following Microsoft document (Hyper-V):
 *
 * http://support.microsoft.com/kb/2870270
 *
 * Comments: Jason.Banham@Nexenta.COM
 *
 * Author: Tony.Huygen@Nexenta.COM
 * Copyright 2013, Nexenta Systems, Inc. All rights reserved.
 * Version: 0.1
 */

fbt::sbd_zvol_unmap:entry
{
        self->tr = 1;
        self->unmap = timestamp;
	printf("%Y\n", walltimestamp);
        stack();
}

fbt::dbuf_free_range:entry
/self->tr/
{
        self->dbuf = timestamp;
}

fbt::dbuf_free_range:return
/self->tr/
{
        @[probefunc] = quantize(timestamp - self->dbuf);
}

fbt::sbd_zvol_unmap:return
/self->tr/
{
        printf("%s takes: %d us", probefunc, (timestamp - self->unmap)/1000);
        printa(@); trunc(@); self->tr = 0;
}

profile:::tick-3sec
{
        printa(@);
}
