#!/bin/sh
plugin_cmd(){
kubectl exec -it \
  $(kubectl get po -n ttc-app -l app.kubernetes.io/instance=wordpress -o name ) \
  -n ttc-app -c wordpress -- wp plugin install "$1" "$2"
}

list(){
  for i in elasticpress jetpack redis-cache woocommerce woocommerce-gateway-paypal-express-checkout woocommerce-product-generator woocommerce-services
  do
    echo "$i"
  done
}

install(){
  list | while read plugin
  do
    plugin_cmd install "${plugin}"
  done

  list | while read plugin
  do
    plugin_cmd activate "${plugin}"
  done
}

uninstall(){
  list | tac | while read plugin
  do
    plugin_cmd deactivate "${plugin}"
  do

  list | tac | while read plugin
  do
    plugin_cmd uninstall "${plugin}"
  done
}

if [ "$1" = "install" ]; then
  install
elif [ "$1" = "delete" -o "$1" = "uninstall" ]; then
  uninstall
fi
