#!/bin/bash

:'
                                    The general logic of the script
    Check Security group ID. If it exist, then continue to check EC2, else -> create Security Group, because SG_ID not found
    Than check EC2 id, if it exist, then ec2 is created and not need to create new instance. If EC2 ID is missing -> then create new EC2 instance
'

#Declare variables
group_id=""
ec2=""
instance_id_check=""
sg_name="MySecurityGroup1"
ami="ami-053b0d53c279acc90"
instance_type="t2.micro"
key_name="aws-server-3"

#Create security group using aws-cli command
create_security_group () {
    create_sg=$(aws ec2 create-security-group --group-name "$sg_name" --description "My security group1")
    echo "$create_sg"
}

#Get Security Group id
get_sg_id () {
    group_id=$(aws ec2 describe-security-groups \
        --filters "Name=group-name,Values=$sg_name" \
        --query "SecurityGroups[0].GroupId" \
        --output text)
    echo "Security group ID:"
    echo "$group_id"
}

#Set SG rules
set_sg_rules () {
    aws ec2 authorize-security-group-ingress \
        --group-id $group_id \
        --protocol tcp \
        --port 22 \
        --cidr 0.0.0.0/0

    aws ec2 authorize-security-group-ingress \
        --group-id $group_id \
        --protocol tcp \
        --port 80 \
        --cidr 0.0.0.0/0

    aws ec2 authorize-security-group-egress \
        --group-id $group_id \
        --protocol all \
        --cidr 0.0.0.0/0

}

#Check if security group exists. If not then create new
check_sg () {
    if [ -n "$group_id" ]; then
        echo "This Security Group already exist"
    else
        echo "Create new Security Group"
        create_security_group
        echo "Get Security Group ID"
        get_sg_id
        echo "Set Security Group rules"
        set_sg_rules
    fi
}

#Create EC2 instance with params and user-data file, which contain apache install and run
create_instance () {
    ec2=$(aws ec2 run-instances --image-id "$ami" \
        --count 1 \
        --instance-type "$instance_type" \
        --key-name "$key_name" \
        --security-group-ids "$group_id" \
        --user-data file://user_data.sh)
}

#Get EC2 id of created instance
get_ec2_id () {
    #Try to get id of created instance. Search 'InstanceId' in creation output and take his value
    instance_id=$(echo "$ec2" | grep -oP '(?<="InstanceId": ")[^"]+' | head -1)
    
    #Check instance id, if ec2 was created in this run of script, then $instance_id will not be None
    #If created instance at first, then: descibe-instances and take $instance_id of created instance ->
    #write this id to file, for remmember it for future; echo this id
    if [ -n "$instance_id" ]; then
        instance_id_check=$(aws ec2 describe-instances --instance-ids $instance_id \
            --query 'Reservations[*].Instances[*].InstanceId' --output text)
        echo "$instance_id" > "last_id.txt"
        echo "Instance ID:"
        echo "$instance_id"
    else
        #if ec2 was created early, not in this iteration, then read file and check ec2 id, what was created in past.
        echo "Instance ID check:"
        instance_id=$(<last_id.txt)
        
        #if instance_id in file not null, then try to get id from describe and check if instance exists
        #if instance exists, or AWS tell, that it exists, then will be return $instance_id_check with ID
        if [ -n "$instance_id" ]; then
            instance_id_check=$(aws ec2 describe-instances \
                --instance-ids $instance_id --query 'Reservations[*].Instances[*].InstanceId' --output text)
        else 
             #else if $instance_id not exist in aws, and ec2 not exist, then will be return None output
            instance_id_check=""
            echo "$instance_id_check"
        fi
    fi
}

#check $instance_id_check variable. If ec2 exist, then value will not be None 
check_ec2 () {
    #if $instance_id_check not none, it means that EC2 is created, or it was terminated, but aws not return this yet
    if [ -n "$instance_id_check" ]; then
        echo "EC2 instance already exists or AWS not tell, that instance was terminated."
        echo "If you shure that instance is terminated, than wait few minutes and try again or delete content from last_id.txt and run script again"
        echo "ID instance:"
        echo "$instance_id_check"
    else
    #else if $instance_id_check is none, than need create new instance
        echo "EC2 instance not exists"
        echo "Create new EC2 instance"
        create_instance
        echo "Get EC2 ID"
        get_ec2_id
    fi
}

#Start work
get_sg_id
check_sg

get_ec2_id
check_ec2


