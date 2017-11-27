#!/bin/bash
#
# Reads linux passwd users and generate an ansible playbook for localhost
#
# Copyright © 2017 by Marcelo Roccasalva, using the GNU GPLv2 license
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# parameters: min_uid
[ -z "$1" ] && {
	echo USAGE: $0 min_uid
	exit 1
}
echo -e "---\n- hosts: localhost"
echo -e "  vars:\n    grupos:"
awk -F: '
ARGIND==1{P[$1]=$2;next}
ARGIND==2{
	if($3>='$1'&&$3<65000){
		printf"      %s:\n",$1
		printf"        gid: %s\n",$3
		GN[$3]=$1;
		if($4){split($4,U,/,/)
		for(i in U){if(GS[U[i]]!=""){GS[U[i]]=GS[U[i]]","$1}else{GS[U[i]]=$1}}}
	}
	next}
USERS!="si"{print "    usuarios:";USERS="si"}
$3>65000{next}
$3>='$1'{
	printf"      %s:\n",$1
	if($5)printf"        comment: \042%s\042\n",$5
	printf"        uid: %s\n",$3
	printf"        group: %s\n",GN[$4]
	printf"        home: %s\n",$6
	if($7)printf"        shell: %s\n",$7
	printf"        password: \042%s\042\n",P[$1]
	if(GS[$1])printf"        groups: %s\n",GS[$1]
	printf"        archivos:\n"
	system("for i in ~"$1"/.ssh/*;do if test -f $i;then echo \042          - arch:\042;echo \042              fn: $i\042;echo \042              fc: |\042;sed \047s/^/                /\047 $i;fi;done")
	
}END{
print "  tasks:\n\
    - name: Create groups\n\
      group:\n\
        name: \042{{ item.key }}\042\n\
        gid: \042{{ item.value.gid }}\042\n\
      with_dict: \042{{ grupos }}\042\n\
    - name: Create users\n\
      user:\n\
        name: \042{{ item.key }}\042\n\
        comment: \042{{ item.value.comment | default(omit) }}\042\n\
        uid: \042{{ item.value.uid | default(omit) }}\042\n\
        group: \042{{ item.value.group | default(omit) }}\042\n\
        home: \042{{ item.value.home | default(omit) }}\042\n\
        shell: \042{{ item.value.shell | default(omit) }}\042\n\
        password: \042{{ item.value.password }}\042\n\
        groups: \042{{ item.value.groups | default(omit) }}\042\n\
      with_dict: \042{{ usuarios }}\042\n\
    - name: Create .ssh dir\n\
      file:\n\
        path: \042{{ item.value.home }}/.ssh\042\n\
        mode: 0700\n\
        owner: \042{{ item.key }}\042\n\
        group: \042{{ item.value.group }}\042\n\
        state: directory\n\
      with_dict: \042{{ usuarios }}\042\n\
    - name: Create .ssh files\n\
      copy:\n\
        dest: \042{{ item.1.arch.fn }}\042\n\
        content: \042{{ item.1.arch.fc }}\042\n\
        mode: 0600\n\
        owner: \042{{ item.0.uid }}\042\n\
        group: \042{{ item.0.group }}\042\n\
      with_subelements:\n\
        - \042{{ usuarios }}\042\n\
        - archivos\n\
"
}' /etc/shadow /etc/group /etc/passwd

