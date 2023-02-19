
Modify `spec.addresses` in the `metallb-conf.yaml` file

```bash
ansible-playbook cluspi_install.yaml -i hosts --verbose --ask-become-pass
ansible-playbook cluspi_uninstall.yaml -i hosts --verbose --ask-become-pass
```