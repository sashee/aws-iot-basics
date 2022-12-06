CA=$(terraform output -raw ca) IOT_ENDPOINT=$(terraform output -raw iot_endpoint) CERT=$(terraform output -raw cert) KEY=$(terraform output -raw key) THING_NAME=$(terraform output -raw thing_name) node index.js

