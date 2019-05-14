#set -x

KUBE_VERSION="v1.14.0"
which kubectl &> /dev/null 
[ ! "$?" -eq 0 ] && echo "downloading kubectl" && curl -L http://dao-get.daocloud.io/kubernetes-release/release/$KUBE_VERSION/bin/linux/amd64/kubectl > /usr/sbin/kubectl && chmod 777 /usr/sbin/kubectl

deploy_file="ovn-setup.yaml ovnkube-db.yaml ovnkube-master.yaml ovnkube-node.yaml"
OUTPUT_DIR="./output"


IMAGE_NAME='daocloud.io/weizhou/ovn-k8s:welan'
NET_CIDR="192.168.0.0/16"
K8S_SRC_CIDR="10.96.0.0/12"
K8S_API_SERVER="https://10.6.185.60:16443"
master_node="$(hostname)"
action="apply"

for opt in $@ ;do
    key=${opt%=*}
    case $key in
        "--image" )
            value=${opt#*=}
            if [ -n "$value" ] ; then
                IMAGE_NAME=`echo $value | sed 's/\"//g' `
            fi 
            echo "set IMAGE_NAME: $IMAGE_NAME"
            ;;

        "--net_cidr" )
            value=${opt#*=}
            if [ -n "$value" ] ; then
                NET_CIDR=`echo $value | sed 's/\"//g' ` 
            fi 
            echo "set NET_CIDR: $NET_CIDR"
            ;;

        "--src_cidr" )
            value=${opt#*=}
            if [ -n "$value" ] ; then
                K8S_SRC_CIDR=`echo $value | sed 's/\"//g' `
            fi 
            echo "set K8S_SRC_CIDR: $K8S_SRC_CIDR"
            ;;

        "--api_server" )
            value=${opt#*=}
            if [ -n "$value" ] ; then
                K8S_API_SERVER=`echo $value | sed 's/\"//g' `
            fi 
            echo "set K8S_API_SERVER: $K8S_API_SERVER"
            ;;

        "--master_node" )
            value=${opt#*=}
            if [ -n "$value" ] ; then
                master_node=`echo $value | sed 's/\"//g' `
            fi 
            echo "set master_node: $master_node"
            ;;

        "apply"|"add")
            action="apply"
            echo "apply"
            ;;

        "delete"|"del")
            action="delete"
            echo "delete"
            ;;
        *)
            echo "error options: $opt"
            exit
    esac
done


if [ "$action" == "apply" ];then
    echo "apply"
    
    kubectl label node ${master_node} node-role.kubernetes.io/master="true" 2> /dev/null

    rm $OUTPUT_DIR -rf
    mkdir $OUTPUT_DIR

    for f in $deploy_file ;do
        cp $f $OUTPUT_DIR
        file="${OUTPUT_DIR}/${f}"
        FLAG="{{image}}"
        DST=${IMAGE_NAME//\//\\\/}
        sed -i 's/'"$FLAG"'/'"${DST}"'/g'   $file
        FLAG="{{net_cidr}}"
        DST=${NET_CIDR//\//\\\/}
        sed -i 's/'"$FLAG"'/'"${DST}"'/g'   $file        
        FLAG="{{svc_cidr}}"
        DST=${K8S_SRC_CIDR//\//\\\/}
        sed -i 's/'"$FLAG"'/'"${DST}"'/g'   $file                
        FLAG="{{k8s_apiserver}}"
        DST=${K8S_API_SERVER//\//\\\/}
        sed -i 's/'"$FLAG"'/'"${DST}"'/g'   $file 
    done

elif [ "$action" == "delete"  ];then
    echo "delete"
else
    echo "error action"
    exit
fi


for f in $deploy_file ;do
    file="${OUTPUT_DIR}/${f}"
    echo "kubectl $action -f $file"
    kubectl $action -f $file
done



