# OCS Inventory

Howto display the backup status in [OCSInventory](http://www.ocsinventory-ng.org/en/)

## Client preparation

Copy the file ntfshardlinkbackup_ocs_plugin.vbs into C:\Program Files\OCS Inventory Agent\Plugins. 

Edit that file and adjust the first 3 lines according to your needs:

```
Dim xmlstatusfiles(1)
xmlstatusfiles(0) = "C:\Logs\network-backup\status.xml"
xmlstatusfiles(1) = "C:\Logs\Backup-To-External-HDD\status.xml"
```

List all your status files here.

### Check the result
Just doubleclick on the ntfshardlinkbackup_ocs_plugin.vbs file. The content of the status file(s) should be displayed.

## Server installation

### Create table in database to store informations

You have to create a new table which will receive new data

````
CREATE TABLE IF NOT EXISTS `ntfshardlinkbackup` (
	`ID` INT(11) NOT NULL AUTO_INCREMENT,
	`HARDWARE_ID` INT(11) NOT NULL,
	`VERSION` VARCHAR(64) DEFAULT NULL,
	`STATUS` VARCHAR(64) DEFAULT NULL,
	`JOBNAME` VARCHAR(255) DEFAULT NULL,
	`LASTRUN` DATETIME DEFAULT NULL,
	`DESTINATION` VARCHAR(255) DEFAULT NULL,
  PRIMARY KEY  (`ID`,`HARDWARE_ID`)
) ENGINE=INNODB ;
````

### Modifiy the engine

You have to modify Map.pm file. On linux, to find the correct version of Map.pm use this command => ````updatedb; locate Map.pm ````

```
ntfshardlinkbackup => {
	mask => 0,
	multi => 1,
	auto => 1,
	delOnReplace => 1,
	sortBy => 'LASTRUN',
	writeDiff => 0,
	cache => 0,
	fields => {
		VERSION => {},
		STATUS => {},
		JOBNAME =>  {},
		LASTRUN =>   {},
		DESTINATION =>  {},
	}
},
```

**Warning: When you will upgrade your OCS Inventory Server, Map.pm will be overwrite. Don't forget to save this file before upgrading.**

### Create the workspace

* create a new folder in the "plugins/computer_detail" directory and name it "cd_ntfshardlinkbackup"
* copy the file "cd_ntfshardlinkbackup.php" into this new folder
* copy your 3 icons (cd_ntfshardlinkbackup*.png) into "plugins/computer_detail/img"

### Activate the plugin

Edit the file /plugins/computer_detail/cd_config.txt

```
<ORDER>
.......
.......
26:cd_ntfshardlinkbackup
</ORDER>
```

```
<LBL>
.......
.......
cd_ntfshardlinkbackup:cd_ntfshardlinkbackup
</LBL>
```

```
<ISAVAIL>
.......
.......
cd_ntfshardlinkbackup:ntfshardlinkbackup
</ISAVAIL>
```

```
<URL>
.......
cd_ntfshardlinkbackup:26
.......
</URL>
```

### Modification of multicriteria search page

The goal is to have possibility to do a multicriteria search on these new data 

Files to modify:

**plugins/language/english/english.txt**

add at the end:

```
6050 NTFS Hardlink Backup
6051 Jobname
6052 Last Run
6053 Destination
6054 Status
```

**plugins/main_sections/ms_multi_search/ms_multi_search.php**

Code to add : 

```
if ($list_id != "")	{	
	$list_fields= array($l->g(652).': id'=>'h.ID',
						$l->g(652).': '.$l->g(46)=>'h.LASTDATE',
						$l->g(652).": ".$l->g(820)=>'h.LASTCOME',
						'NAME'=>'h.NAME',
						$l->g(652).": ".$l->g(24)=>'h.USERID',
						$l->g(652).": ".$l->g(25)=>'h.OSNAME',
						..............
						$l->g(652).": ".$l->g(1247)=>'h.ARCH',

						$l->g(6050).": ".$l->g(6051)=>'ntfshardlinkbackup.JOBNAME',
						$l->g(6050).": ".$l->g(6052)=>'ntfshardlinkbackup.LASTRUN',
						$l->g(6050).": ".$l->g(6053)=>'ntfshardlinkbackup.DESTINATION',
						$l->g(6050).": ".$l->g(6054)=>'ntfshardlinkbackup.STATUS',
						);
```

```
	$tab_options['AS']['h.NAME']="name_of_machine";
	$query_add_table="";

	$query_add_table.=" left join ntfshardlinkbackup on h.id=ntfshardlinkbackup.hardware_id ";
```


```
$sort_list=array("NETWORKS-IPADDRESS" =>$l->g(82).": ".$l->g(34),
				 "NETWORKS-MACADDR"=>$l->g(82).": ".$l->g(95),
				 "SOFTWARES-NAME"=>$l->g(20).": ".$l->g(49),
				............
				 "CPUS-SOCKET"=>$l->g(54).": ".$l->g(1316),

 				 "NTFSHARDLINKBACKUP-JOBNAME"=>$l->g(6050).": ".$l->g(6051),
 				 "NTFSHARDLINKBACKUP-LASTRUN"=>$l->g(6050).": ".$l->g(6052),
 				 "NTFSHARDLINKBACKUP-DESTINATION"=>$l->g(6050).": ".$l->g(6053),
 				 "NTFSHARDLINKBACKUP-STATUS"=>$l->g(6050).": ".$l->g(6054),
				 );
```

```
$optSelectField=array( "NETWORKS-IPADDRESS"=>$sort_list["NETWORKS-IPADDRESS"],
			   "NETWORKS-MACADDR"=>$sort_list["NETWORKS-MACADDR"],//$l->g(82).": ".$l->g(95),
			   "SOFTWARES-NAME"=>$sort_list["SOFTWARES-NAME"],//$l->g(20).": ".$l->g(49),
			   "SOFTWARES-VERSION"=>$sort_list["SOFTWARES-VERSION"],//$l->g(20).": ".$l->g(277),
			   "SOFTWARES-BITSWIDTH"=> $sort_list["SOFTWARES-BITSWIDTH"],
			   "SOFTWARES-PUBLISHER"=> $sort_list["SOFTWARES-PUBLISHER"],
			   "SOFTWARES-COMMENTS"=>$sort_list["SOFTWARES-COMMENTS"],
			   "HARDWARE-DESCRIPTION"=>$sort_list["HARDWARE-DESCRIPTION"],//$l->g(25).": ".$l->g(53),
			   ...............................
			   "CPUS-VOLTAGE-SELECT"=>array("exact"=>$l->g(410),"small"=>$l->g(201),"tall"=>$l->g(202)),
			    
 			   "NTFSHARDLINKBACKUP-JOBNAME"=>$sort_list["NTFSHARDLINKBACKUP-JOBNAME"],
			   "NTFSHARDLINKBACKUP-LASTRUN"=>$sort_list["NTFSHARDLINKBACKUP-LASTRUN"],
			   "NTFSHARDLINKBACKUP-LASTRUN-LBL"=>"calendar",
			   "NTFSHARDLINKBACKUP-LASTRUN-SELECT"=>array("small"=>$l->g(346),"tall"=>$l->g(347)),
			   "NTFSHARDLINKBACKUP-DESTINATION"=>$sort_list["NTFSHARDLINKBACKUP-DESTINATION"],
			   "NTFSHARDLINKBACKUP-STATUS"=>$sort_list["NTFSHARDLINKBACKUP-STATUS"],
			   );
```

```
$sort_list_2Select=array("HARDWARE-USERAGENT"=>"OCS: ".$l->g(966),
						 "DEVICES-IPDISCOVER"=>$l->g(107).": ".$l->g(312),
						 "DEVICES-FREQUENCY"=>$l->g(107).": ".$l->g(429),
						 "GROUPS_CACHE-GROUP_ID"=>$l->g(583).": ".$l->g(49),
						 .................
			   			 "CPUS-CURRENT_ADDRESS_WIDTH"=>$l->g(54).": ".$l->g(1313),
						  
						 "NTFSHARDLINKBACKUP-JOBNAME"=>$l->g(6050).": ".$l->g(6051),
 						 "NTFSHARDLINKBACKUP-LASTRUN"=>$l->g(6050).": ".$l->g(6052),
 				 		 "NTFSHARDLINKBACKUP-DESTINATION"=>$l->g(6050).": ".$l->g(6053),
 						 "NTFSHARDLINKBACKUP-STATUS"=>$l->g(6050).": ".$l->g(6054),
						 );
```


**require/function_search.php**

change the line

```
if ($field == "LASTDATE" or $field == "LASTCOME" or $field == "REGVALUE"){
```

to

```
if ($field == "LASTDATE" or $field == "LASTCOME" or $field == "REGVALUE" or $field == "LASTRUN"){
```
