#!/bin/bash

#latitude for cannington
lat="-31.977707"
lon="115.889388"

#latitude for daglish
# lat="-31.948360"
# lon="115.815247"

#latitude for cannington
# lat="-32.010128"
# lon="115.946725"

time="12:05:20"


#takes stop_id an an argument.
find_trips(){
	awk -F, -v id="$1" '$4==id{print $0}' all_trains_you_can_catch.txt | sort -t$',' -k3 | head -n 1
}


#given parent station , it returns all the station_id within the parent station

find_all_station_in_parent(){
	awk -F, -v p_id=$1 '$2==p_id{print $3}' train_stations.txt
}


update_all_trains_you_can_catch()
{

	#update all trains that you can catch
	#any stops that have arrival time < given time is returned 
	eval "stop_ids=($2)"
	 for id in ${stop_ids[@]};do
		# var=$(awk -F, -v id=$id '$4==id{print $0}' data/stop_times.txt | awk -F, -v start_time=$1 '{split($3,t,":");split($start_time,y,":");time=t[1]t[2]t[3]; rt=y[1]y[2]y[3]; if(rt<time){print $0}}')
		awk -F, -v id=$id '$4==id{print $0}' data/stop_times.txt | awk -F, -v start_time=$1 '{split($3,t,":");split(start_time,y,":");
		train_times=t[1]t[2]t[3]; your_time=y[1]y[2]y[3];
		if(train_times>your_time){print $0}
		}'
		
	done
	
}

get_trip_itenerary()
{
	cat data/stop_times.txt | awk -F,  -v trip_id=$1 '$1==trip_id{print $0}'
}

final_function()
{
	echo "YOU WILL REACH FREMANTLE STATION AT: $2"
	exit 1
}


#-------------------START PROGRAM --------------

echo "START-TIME (HOME): $time "
#condenses all the stations to show the train station, saved in a text file
awk -F, '$NF~/Rail/{print}' data/stops.txt > train_stations.txt

#entry stores the shortest distance and references the corresponding entry using index , entry hols two fields distance and index of nearest station
entry=$(awk -v lat=$lat -v lon=$lon -F,  '{OFS=",";print lat,lon, $7, $8}' train_stations.txt| awk -F, -f haversine.awk | sort -n | head -n 1)
#extracts first field of entry which is the distance
index=$(echo $entry | awk '{print $2}')
#contains the information about the station that is closes to the given location
#stop_details have the details of the nearest station as in stops.txt
stop_details=$(cat train_stations.txt| head -"$index" |tail -1)
nearest_train_station=$(echo $stop_details | awk -F, '{print $5}')
echo "START STATION: $nearest_train_station"

distance_to_station=$(echo $entry | awk '{print $1}')
d_t_s=${distance_to_station%.*}
echo -e "DISTANCE TO THE STATION IN METERS: $d_t_s"
ttw=$(echo "$d_t_s / 80"| bc -l)
ttw=${ttw%.*}
echo "TIME TO WALK: $ttw minutes"

#uncomment the below command for mac based users. Date function works different in mac
#time=$(gdate -d "$time $ttw minutes" +'%H:%M:%S')
time=$(date -d "$time $ttw minutes" +'%H:%M:%S')

echo "REACH $nearest_train_station : $time"
#grabs the parent node from the given entry
#if there is a parent node present, it denotes there migt be other possible platforms within the station denoted by unique stop_id 
parent=$(echo $stop_details | awk -F, '{print $2}')
if [[ -z $parent ]];
then
	parent2=$(echo $stop_details | awk -F, '{print $3}')
	stop_id=$(awk -F, -v parent="$parent2" '$2==parent{print $3}' train_stations.txt)

else
	stop_id=$(awk -F, -v parent="$parent" '$2==parent{print $3}' train_stations.txt)

fi 
#stop_id contains all the platforms within a station.
#converting the stop_id into array, if first instance, there might be multiple pllatforms within a station
eval "nearest_stop_ids=($stop_id)"


possible_trips=[]


#calling function to update the train time tables, takes the stop id and time to get the relevant time tables
update_all_trains_you_can_catch $time "$stop_id" > all_trains_you_can_catch.txt
#update_all_trains_you_can_catch $time "$stop_id" 


#finding possible trips for the nearest station defined by nearest_stop_ids
#All trips that can be caught starting now at the train station.
for id in ${nearest_stop_ids[@]};do
	possible_trips[$id]="$(find_trips $id)"
done

#possible trips will have the latest times you can catch a train for each stop regardless of the direction it is going to.

#finad_all_station_in_parent finds all the platforms for given id.

eval "transit1=($(find_all_station_in_parent 56))"
eval "transit2=($(find_all_station_in_parent 64))"
eval "freo=($(find_all_station_in_parent 87))"
train_ride_start=""
perth_transit=""
transit_no=0
next_train_time=""

#for all the trips in array possible trips
for trip_details in ${possible_trips[@]};do
	if [ $trip_details != "[]" ]; then

		#gets trip id
		 trip=$(echo $trip_details | awk -F, '{print $1}')
		 #gets stop id
		 destination=$(awk -F, -v trip="$trip" '$3==trip{print $0}' data/trips.txt )
		 stop_station=$(echo $destination | awk -F, '{print $6}')
		 trip_id=$(echo $destination | awk -F, '{print $3}')
		 #sorting according to time to get the final station in possible transit stations
		 awk -F, -v stop="$stop_station" -v trip="$trip_id" '$1==trip{ print $0}' data/stop_times.txt | sort  -t$',' -k2 > possible_transit_stations.txt 
		 location=$(cat possible_transit_stations.txt | tail -1 |awk -F, '{print $4}')
		#if the last station is fremantle
		if [[ "${freo[@]}" =~ " ${location}" ]];then
		 	dst_time=$(cat data/stop_times.txt | awk -F, -v drop_off=$location -v trip_id=$trip_id '$1==trip_id{if($4 == drop_off){print $0}}'| awk -F, '{print $2}' )
		 	train_ride_start=$(echo $trip_details | awk -F, '{print $3}')
		 	final_function "$train_ride_start" "$dst_time" "$trip"  
		 	#stop id contains array of stops in a station, dst time is the time to reach the destination, $trip has trip id in it, $destination has infromation on the final station
		 	break;
		 #if the last station is perth
		elif [[ "${transit1[@]}" =~ " ${location}" ]]; then
			next_train_time=$(echo $trip_details | awk -F, '{print $3}')
			perth_transit=$(cat data/stop_times.txt | awk -F, -v drop_off=$location -v trip_id=$trip_id '$1==trip_id{if($4 == drop_off){print $0}}')
			dst_time=$(cat data/stop_times.txt | awk -F, -v drop_off=$location -v trip_id=$trip_id '$1==trip_id{if($4 == drop_off){print $0}}'| awk -F, '{print $2}' )
			time=$dst_time
			let transit_no=1
			train_ride_start=$(echo $trip_details | awk -F, '{print $3}')
			continue
		#if the last station is perth underground
		elif [[ "${transit2[@]}" =~ " ${location}" ]]; then
			if [[ $transit_no == 1 ]]; then
				continue
			else
				let transit_no=2
				perth_transit=$(cat data/stop_times.txt | awk -F, -v drop_off=$location -v trip_id=$trip_id '$1==trip_id{if($4 == drop_off){print $0}}')
				continue
			fi
			
		else
			continue

		fi
	fi
done

#99007 is platform 7 where the train for fremantle leaves.
stop="99007"
echo "TRAIN ARRIVAL TIME: $train_ride_start"
echo "ARRIVAL AT PERTH: $time"

echo "DROP OFF AT PERTH STATION"
echo "WALK TO PLATFORM 7"
#update_time
#need to make this dynamic 
echo "TIME TO REACH TERMINAL 7: 5"
#uncomment line below for Unix based mac users. date function uses different argument in mac
#time=$(gdate -d "$time 5 minutes" +'%H:%M:%S')
time=$(date -d "$time 5 minutes" +'%H:%M:%S')

echo "ARRIVAL IN PLATFORM 7: $time"

update_all_trains_you_can_catch $time $stop > all_trains_you_can_catch.txt

cat all_trains_you_can_catch.txt | sort -t$"," -k3 | while read line;
 do 
 	trip=$(echo $line | awk -F, '{print $1}')
 	#trip_itenenary=$(cat data/stop_times.txt | awk -F,  -v trip_id=$trip '$1==trip_id{print $0}')
 	trip_itenenary=$(get_trip_itenerary $trip)
 	next_train=$(echo $trip_itenenary| head -n 1 | awk -F, '{print $0}')
 	transit_train_time=$(echo $next_train | awk -F, '{print $3}')
 	init=$(echo $next_train | awk -F, '{print $4}')
 	if [[ $init == $stop ]]; then
 		echo "NEXT TRAIN TO FREMANTLE DEPARTURE TIME: $transit_train_time "
 		destination=$(echo "$trip_itenenary" | tail -1)
 		dst_time=$(echo $destination | awk -F, '{print $3}' )
 		trip=$(echo $destination | awk -F, '{print $1}' ) 
 		final_function "$train_ride_start" "$dst_time" "$trip"  
 		break;
 	else
 		continue 
 	fi
 	
 done
# trip_details=$(update_all_trains_you_can_catch $time2 $stop | sort -t$"," -k2 |head -n 1)
# echo $trip_details

# trip_id=$(echo $trip_details | awk -F, '{print$1}')

# cat data/stop_times.txt | awk -F, -v id="$trip_id" '$1==id{print $0}'

 






