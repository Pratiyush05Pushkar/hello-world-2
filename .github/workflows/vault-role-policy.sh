#!/bin/shell

for val in $1 ;
do 
yq r $val "spec.parameters.objects" > object.yaml
cat object.yaml
all_secret_paths=$(yq r object.yaml "[].secretPath")
final_policy=""
unique_secret_paths=$(echo "$all_secret_paths" |sort|uniq)
echo $all_secret_paths ;
echo $unique_secret_paths ;
for val in $unique_secret_paths ;
do
final_policy+="\n path \\\"${val}\\\" { \n \t capabilities = [\\\"read\\\"] \n } \n"
echo $val
done
final_policy=\"$final_policy\"
echo $final_policy
cat > payload.json <<-EOF
{
"policy": ${final_policy}
}
EOF
cat payload.json
policy_name="$(yq r $val "metadata.name" )_policy"
role_name="$(yq r $val "metadata.name" )_role"
service_account_name=$(yq r $val "metadata.labels.serviceAccountName" )
service_namespace=$(yq r $val "metadata.labels.namespace" )
curl --header "X-Vault-Token:${{ secrets.VAULT_POLICY_UPDATE_TOKEN }}" --request POST --data @payload.json https://vault.eng.livspace.com/v1/sys/policy/apps/$policy_name          
cat > payload.json << EOF
{
"name": "${role_name}",
"bound_service_account_names": "${service_account_name}",
"bound_service_account_namespaces": "${service_namespace}",
"token_policies": "${policy_name}"
}
EOF
cat payload.json
curl --header "X-Vault-Token:${{ secrets.VAULT_POLICY_UPDATE_TOKEN }}" --request POST --data @payload.json https://vault.eng.livspace.com/v1/auth/kubernetes/role/$role_name    
rm -f object.yaml payload.json
done