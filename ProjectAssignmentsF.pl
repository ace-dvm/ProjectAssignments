use strict;
use warnings;
use diagnostics;
use feature 'say';
use Data::Dumper;

#pull in the file
my $todays_data = 'choices.txt';
open INFILE, "$todays_data";
my @data = <INFILE>;
close INFILE;

#initialize vars
my @TS;
my @DS;
my @DM;

my @groups; 

# read the data from the file
for my $line (@data){
	$line =~ s/\n//g;
	my @items = split /;/, $line;
	my %group = ("names" => $items[0], "size" => $items[1], "pref1" => $items[2], "pref2" => $items[3], "pref3" => $items[4], "priority" => $items[1]);
	push @groups, \%group;
	}
say "read file";

#separate into arrays by 1st preference
for my $group (@groups){
	my %h = %{$group};
#print Dumper (\%h);
	my $pref = $h{pref1};
	$pref =~ s/^\s+|\s+$//g;
	if ($pref eq "TS"){push @TS, \%h;}
	if ($pref eq "DS"){push @DS, \%h;}
	if ($pref eq "DM"){push @DM, \%h;}
}

say "separated";

#clean arrays of any null values
@TS = grep defined && $_, @TS;
@DS = grep defined && $_, @DS;
@DM = grep defined && $_, @DM;

say "cleaned";

#deal with solos (topics with 1 group of size 1 and no groups of size 2)

solos(\@TS, "TS", \@DS, "DS", \@DM, "DM");
solos(\@DS, "DS", \@DM, "DM", \@TS, "TS");
solos(\@DM, "DM", \@TS, "TS", \@DS, "DS");


say "solos dealt with";

#consolidate groups of size 1
@TS = mergeOnes(@TS);
@DS = mergeOnes(@DS);
@DM = mergeOnes(@DM);

say "consolidated";

@TS = customSort(\@TS);
@DS = customSort(\@DS);
@DM = customSort(\@DM);

say "sorted";

while (1){
	my @largestGroup = whichGroupIsLargest();
	my @smallestGroup = whichGroupIsSmallest();
	my $largestGroupID = shift @largestGroup;
	my $largestGroupRef = shift @largestGroup;
	my $smallestGroupID = shift @smallestGroup;
	my $smallestGroupRef = shift @smallestGroup;	
	
	if((scalar @$largestGroupRef - scalar @$smallestGroupRef) <= 1){
            last;
	}
	
	#set the middle group - start with the hypothesis that DS is the middle group and test it
		my $middleGroupID = "DS";
		my $middleGroupRef = \@DS;
		if($largestGroupID eq $middleGroupID){
			$middleGroupID = "TS";
			$middleGroupRef = \@TS;
		} else {
			if($smallestGroupID eq $middleGroupID){
				$middleGroupID = "TS";
				$middleGroupRef = \@TS;
			}
		} #if TS is also not the middle group, this should fix the problem
		if($largestGroupID eq $middleGroupID){
			$middleGroupID = "DM";
			$middleGroupRef = \@DM;
		} else {
			if($smallestGroupID eq $middleGroupID){
				$middleGroupID = "DM";
				$middleGroupRef = \@DM;
			}
		}

	#get the index of the group to move
	my $foundGroup = 0;
	my $index = 0;

	while ($index < scalar @$largestGroupRef && $foundGroup == 0){
		my $groupRef = ${ $largestGroupRef }[$index];
		if(${ $groupRef }{priority} != 1 && ${ $groupRef }{pref2} eq $smallestGroupID){
			$foundGroup = 1;
			splice @{ $smallestGroupRef }, 0, 0, splice @{ $largestGroupRef }, $index, 1;
			last;
		}
		$index++;
	}
	#if we failed to find a group to move, try moving one from the middle group to the smallest group instead.
	if($foundGroup == 0){
		$index = 0;
		while ($index < scalar @$middleGroupRef && $foundGroup == 0){
			my $groupRef = ${ $middleGroupRef }[$index];
			if(${ $groupRef }{priority} != 1 && ${ $groupRef }{pref2} eq $smallestGroupID){
				$foundGroup = 1;
				splice @{ $smallestGroupRef }, 0, 0, splice @{ $middleGroupRef }, $index, 1;
				last;
			}
			$index++;
		}
	}
	#if we still didn't find a group, try to grab a group of size 2 from the largest group.
	if($foundGroup == 0){
		$index = 0;
		while ($index < scalar @$largestGroupRef && $foundGroup == 0){
			my $groupRef = ${ $largestGroupRef }[$index];	
			if(${ $groupRef }{priority} == 2){
				$foundGroup = 1;
				splice @{ $smallestGroupRef }, 0, 0, splice @{ $largestGroupRef }, $index, 1;
				last;
			}
			$index++;
		}
	}
	#failing that, just grab a group of size 3 from the largest group
	if($foundGroup == 0){
		$index = (scalar @$largestGroupRef) - 1;		
		splice @{ $smallestGroupRef }, 0, 0, splice @{ $largestGroupRef }, $index, 1;
	}
	
};

say "equalized";

saygroups();

####### subs ########

sub hasSolo{
        #initialize vars
	my @prefGroup = @_;
	if(scalar @prefGroup == 0){
            return 0;
	}
	
	my $nrGpSize1 = 0;
	my $nrGpSize2 = 0;
	
	#count nr of groups of size 1 and 2
	for my $group (@prefGroup){
            if (${$group}{size} == 1){$nrGpSize1++;}
            if (${$group}{size} == 2){$nrGpSize2++;}
	}
	
	if($nrGpSize1 == 1 && $nrGpSize2 == 0){
           return 1; 
	} else {return 0;}
}

sub getSecondChoice{
    my $topicRef = $_[0];   
    my $index2 = 0;
    my $foundGroup = 0;
    my $pref2 = $_[1];
    
    while ($index2 < scalar @$topicRef){
        my $groupRef = ${ $topicRef }[$index2];
        my $priority = ${ $groupRef }{priority};
        my $pref = ${ $groupRef }{pref2};
        if($priority == 2 && $pref eq $pref2){
            $foundGroup = 1;
            return ($foundGroup, $topicRef, $index2);
        }
        $index2++;
    }
    return ($foundGroup, $topicRef, $index2);
}


sub mergeOnes{
        #initialize vars
	my @prefGroup = @_;
	my $nrGpSize1 = 0;
	my $nrGpSize2 = 0;
	
	#count nr of groups of size 1 and 2
	for my $group (@prefGroup){
            if (${$group}{size} == 1){$nrGpSize1++;}
            if (${$group}{size} == 2){$nrGpSize2++;}
	}
say "counted";

	while (($nrGpSize2 >= $nrGpSize1 || $nrGpSize1 - $nrGpSize2 >= 2) && $nrGpSize1 != 0 && $nrGpSize2 != 0) {
		my $array_size = scalar @prefGroup;				
		my $index = 0;
		while ($index < $array_size && $nrGpSize1 != 0 && $nrGpSize2 != 0){
			my $group = $prefGroup[$index];
			if (${$group}{size} == 1){
				my $index2 = 0;
				while ($index2 < $array_size && $nrGpSize1 != 0 && $nrGpSize2 != 0){
					my $group2 = $prefGroup[$index2];
					if(${$group2}{size} == 2){
						${$group}{names} = ${$group}{names} . ", " . ${$group2}{names};	
						${$group}{size} += ${$group2}{size};
						splice @prefGroup, $index2, 1;
						$nrGpSize1--;
						$nrGpSize2--;
						$array_size--;
						last;
					}
					$index2++;
				}
			}
			$index++;
		}		
	}
	while ($nrGpSize1 >1){	
		if($nrGpSize1 == 2 || $nrGpSize1 == 4){
			my $array_size = scalar @prefGroup;				
			my $index = 0;
			while ($index <= $array_size){
				my $group = $prefGroup[$index];				
				if (${$group}{size} == 1){
				my $index2 = 0;
					while ($index2 <= $array_size){
						my $group2 = $prefGroup[$index2];
						if (${$group2}{size} == 1 && ${$group}{names} ne ${$group2}{names}){
							${$group}{names} = ${$group}{names} . ", " . ${$group2}{names};	
							${$group}{size} += ${$group2}{size};
							splice @prefGroup, $index2, 1;
							$nrGpSize1--;
							$nrGpSize1--;
							$array_size--;
							last;
						}
						$index2++;
					}				
				}
				$index++;
			}
		} else {
			my $index = 0;
			my $array_size = scalar @prefGroup;	
			while ($index <= $array_size){
			my $group = $prefGroup[$index];
				if (${$group}{size} == 1){
					my $index2 = 0;
					while ($index2 <= $array_size){
						my $group2 = $prefGroup[$index2];	
						if (${$group2}{size} == 1 && ${$group}{names} ne ${$group2}{names}){
							my $index3 = 0;
							while ($index3 <= $array_size){
								my $group3 = $prefGroup[$index3];
								if (${$group3}{size} == 1 && ${$group}{names} ne ${$group3}{names} && ${$group2}{names} ne ${$group3}{names}){
									${$group}{names} = ${$group}{names}. ", " . ${$group2}{names} . ", " . ${$group3}{names} ;	
									${$group}{size}  = ${$group}{size}+ ${$group2}{size} + ${$group3}{size};
									#say $index;
									splice @prefGroup, $index2, 1;
									$index3--;
									#say $index2;
									splice @prefGroup, $index3, 1;
									$nrGpSize1--;
									$nrGpSize1--;
									$nrGpSize1--;
									$array_size--;
									$array_size--;
									last;
								}
								$index3++;
							}
							last;
						}
						$index2++;
					}
					last;
				}	
				$index++;				
			}	
		}
	}
return @prefGroup;
}
	
sub whichGroupIsLargest	{
	my $largestGroup = scalar @TS;
	my $groupID = "TS";
	my $groupRef = \@TS;
	if (scalar @DS > $largestGroup){
		$largestGroup = scalar @DS;
		$groupID = "DS";
		$groupRef = \@DS;
	}
	if (scalar @DM > $largestGroup){
		$groupID = "DM";
		$groupRef = \@DM;
	}
	return ($groupID, $groupRef);
}

sub whichGroupIsSmallest {
	my $smallestGroup = scalar @TS;
	my $groupID = "TS";
	my $groupRef = \@TS;
	if (scalar @DS < $smallestGroup){
		$smallestGroup = scalar @DS;
		$groupID = "DS";
		$groupRef = \@DS;
	}
	if (scalar @DM < $smallestGroup){
		$groupID = "DM";
		$groupRef = \@DM;
	}
	return ($groupID, $groupRef);
}


sub saygroups{
	print "TS {";
	saygroup(\@TS);
	print "} \n\n DS {";
	saygroup(\@DS);
	print "} \n\n DM {";
	saygroup(\@DM);
	print "}";
}

sub saygroup{
	my @topic = @{$_[0]};
	if(scalar @topic > 0){
            for my $group ( @topic ) {
		print "names = ", ${$group}{names};
		print "; size = ", ${$group}{size};
		print "; pref1 = ", ${$group}{pref1};
		print "; pref2 = ", ${$group}{pref2};
		print "; pref3 = ", ${$group}{pref3};
		print "; priority = ", ${$group}{priority}, "\n";
            }
        }
}

sub solos{
	my $Ref1 = $_[0];
	my $ID1 = $_[1];
	my $Ref2 = $_[2];
	my $ID2 = $_[3];
	my $Ref3 = $_[4];
	my $ID3 = $_[5];
	say $Ref1;
	say $ID1;

	if(hasSolo(@{ $Ref1 })){
		my $index1 = 0;
		#get the index of the group of size 1
		while ($index1 < scalar @$Ref1){
			my $groupRef = ${ $Ref1 }[$index1];
				if(${ $groupRef }{priority} == 1){
		                    last;
				}
		        $index1++;
    		}
    		
    		my $group1Name = ${ $Ref1 }[$index1]{names};
    	
    		#search the other topics for a group of size 2 with pref2 = ID1
    		my @secondChoice = getSecondChoice($Ref2,$ID1);
    		
    		if ($secondChoice[0] == 0){ #if foundGroup == false
			@secondChoice = getSecondChoice($Ref3, $ID1);
   		 }
    		
		if ($secondChoice[0] == 1){
			#combine the groups
			my $topicRef = $secondChoice[1];
			my $group2Names = ${ $topicRef }[$secondChoice[2]]{names};
			${ $Ref1 }[$index1]{names} = $group1Name . ", " . $group2Names;
			${ $Ref1 }[$index1]{size} = 3;
			#delete the group out of the other array
			splice @{ $secondChoice[1] }, $secondChoice[2], 1;
		        
    		} else {
			#break up a group of size 3 with ID1 as their first choice; repay them by setting priority = 1
			my $index3 = 0;
			#get the index of a group of size 3
			while ($index3 < scalar @$Ref1){
				my $groupRef = ${ $Ref1 }[$index3];
				if(${ $groupRef }{priority} == 3){
					last;
				}
				$index3++;
			}
			    my $group3Names = ${ $Ref1 }[$index3]{names};
			    my($first, $rest) = split(/,/, $group3Names, 2);
			    ${ $Ref1 }[$index1]{names} = $group1Name . ", " . $first;
			    ${ $Ref1 }[$index3]{names} = $rest;
			    ${ $Ref1 }[$index1]{size} = 2;
			    ${ $Ref1 }[$index3]{size} = 2;
			    ${ $Ref1 }[$index3]{priority} = 1;
		}  
	}
	
sub customSort {
	#sort all groups by priority
	my $topic_ref = $_[0];
	my @priority1;
	my @priority2;
	my @priority3;
	my @sorted_array;
	
	for my $group (@{ $topic_ref }) {
		# for each element in topic, create 3 arrays: priority 1, 2, 3
	  	if (%$group{priority} == 1){push @priority1, $group;}
	  	if (%$group{priority} == 2){push @priority2, $group;}
	  	if (%$group{priority} == 3){push @priority3, $group;}
	}
	
	@priority1 = reverse @priority1;
	@priority2 = reverse @priority2;
	@priority3 = reverse @priority3;
	
	@sorted_array = (@priority1, @priority3, @priority3);
	
	return @sorted_array;
	
	}
}

