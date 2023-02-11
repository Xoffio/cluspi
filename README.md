
Modify `spec.addresses` in the `metallb-conf.yaml` file

```bash
ansible-playbook ku_control_install.yaml -i hosts --verbose
ansible-playbook ku_control_uninstall.yaml -i hosts --verbose
```