## [1.9.1](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/1.9.0...1.9.1) (2022-06-15)

### Bug Fixes

- **hub-config/deploy:** Remove obsolete Hive patch ([e5e7530](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/e5e7530d9d64a7c46cf7399a7782bec592938756))

# [1.9.0](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/1.8.4...1.9.0) (2022-06-10)

### Features

- Do the detach ([c41286e](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/c41286eb2fadd9a2ce942a12355d14378622ef11))

## [1.8.4](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/1.8.3...1.8.4) (2022-06-10)

### Bug Fixes

- **registry:** Add certificate to OpenShift objects to be able to pull after ICSP ([0495654](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/04956541ca18672459aaa5ab5bda10eedc6f1e36))

## [1.8.3](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/1.8.2...1.8.3) (2022-06-02)

### Bug Fixes

- change default size vm and odf storagecluster manifest to 75 ([7724bc2](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/7724bc2fbb28248c4a93f2ecdea113c11b2ff99c))
- mgmt-10251-change default size vm and odf storagecluster manifest to 1 ([#337](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/issues/337)) ([13f21c7](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/13f21c7654838fcde7f9d38fd6606bcbbfff1048))
- remove to default vm value and odf storagecluster manifest to 1 ([120de6a](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/120de6aab99d1dabaae2e643d5f635f04fa694a4))

## [1.8.2](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/1.8.1...1.8.2) (2022-05-31)

### Bug Fixes

- **Containerfile:** add netcat for SNO DNS testing and workaround ([9ddd7a8](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/9ddd7a8fefdf39dab677e6231d909bb5cb845986))

## [1.8.1](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/1.8.0...1.8.1) (2022-05-30)

### Bug Fixes

- **metallb:** update nmstate api to v1 ([f5b329d](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/f5b329db9360a07860b7d77d64be2756f870ffb5))

# [1.8.0](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/1.7.1...1.8.0) (2022-05-30)

### Features

- **ci:** set motd based on final workflow status ([ca6caa1](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/ca6caa129cf81437e017b0ea3292bb5a5c39a8c4))

## [1.7.1](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/1.7.0...1.7.1) (2022-05-30)

### Bug Fixes

- **Makefile:** do not ask for confirmation for deleting vms ([ae1f274](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/ae1f2747a9f6d07d51238bdde332119343e8121b))

# [1.7.0](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/1.6.0...1.7.0) (2022-05-28)

### Bug Fixes

- **deploy-acm:** Check correct type ([039a957](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/039a9579284524622d8aef0692f6727a5a0d4ff1))
- **deploy-worker:** field grabbing was not done properly ([f86393b](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/f86393b1bff60d0811f73175147e69a798f0cc03))
- **detach:** Add missing kubeconfig to the calls for check_resource ([0fa510b](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/0fa510bc26536c3fe19d033e5f9b471dec1d9747))
- **render_worker:** Give some time for worker to be created after applying manifests ([fbab8f5](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/fbab8f59aa7fd9abe6909e6ee19c5670e969b508))

### Features

- Add debug.. ([921dc9d](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/921dc9d762c24e36fe3e5c6b7dfe37bf3aaae8e3))

# [1.6.0](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/1.5.1...1.6.0) (2022-05-28)

### Bug Fixes

- Apply certificate from registry also on workers ([6223089](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/6223089117344af05ba9678e16d40a286f94e6e4))
- **deploy-acm:** Check correct type ([2890ba1](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/2890ba128f98a7d154807c55cda6d1314837977c))
- **deploy-worker:** field grabbing was not done properly ([9497782](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/94977825df6c6e50c84467abd5cc941383d3cfd1))
- **detach:** Add missing kubeconfig to the calls for check_resource ([15351a1](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/15351a1a8eca24a212fed93520bc245c4f567ead))
- **Makefile:** do not ask for confirmation for deleting vms ([9b5a62b](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/9b5a62b62404262275abfc8c2d123c0d623596e9))
- **ODF:** Set back replicas to 3 because of lack of stability ([0f1b78f](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/0f1b78ff23e2b25990c93ac36e81f187ebce26ba))
- **render_edgeclusters.sh:** Fix interface iteration for creating ignored entries ([6db7348](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/6db73483af229e904264f2d8bb4e9e7bcf42d1a7))
- **render_worker:** Give some time for worker to be created after applying manifests ([fefbc74](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/fefbc7438c0001e0e756e263efbb888dacf1801c))

### Features

- Add debug.. ([7441d38](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/7441d38bf614a250c5466d869cf0686bf8c3adf0))

## [1.5.1](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/1.5.0...1.5.1) (2022-05-24)

### Bug Fixes

- **Makefile:** Properly revert changes in commit 0f63eb190a21788d0b521b1d741b11bf9878c6f3 ([8074815](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/807481514a12ba70435d7ce0cb2ef1934c78a259))

# [1.5.0](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/1.4.5...1.5.0) (2022-05-24)

### Bug Fixes

- **ansible:** control hub and edge function errors properly ([14f24d5](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/14f24d508d92fba5c3c879b555d7aa23fc41e134))
- **ci:** adapt ui ci to new workflow ([f617b20](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/f617b20cb2dc63955a81cd9a3a001104c6cc6430))
- **odfdeploy:** apply labels only to master nodes ([f52936c](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/f52936c32916f724fe1593cdcdeceac29f73dfa1))
- **README.md:** Fake fix to trigger tagging ([4d28b62](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/4d28b629fcf5f096b31aa17e0dfe879e967438a0))
- **registry:** fix the registry route check ([8c52d6d](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/8c52d6d323eaab5db63d4eed08514000b5bbe06d))
- **registry:** selinux patch to handle BZ[#2033639](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/issues/2033639) ([69aab83](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/69aab83a994a7d7d5acae1cdcdad01f2fc268afb))

### Features

- **ansible:** add function edge to export edge kubeconfig ([7938dd8](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/7938dd8e84c53495480eb0b786703098684b4ec6))
- **ansible:** add hub kubeconfig alias to bashrc ([fbf4624](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/fbf4624fc61d9e790f354c4acdfcc10623cecff0))
- **ansible:** add some minor tweak to bashrc ([a3f333d](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/a3f333d23a7b288e977ab94cfbb9f417760a2942))
- **ci:** show in motd when a job has failed ([6a56d33](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/6a56d3354198c1be26438837228b85739e7e20f3))

# [1.5.0](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/1.4.5...1.5.0) (2022-05-23)

### Bug Fixes

- **ansible:** control hub and edge function errors properly ([14f24d5](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/14f24d508d92fba5c3c879b555d7aa23fc41e134))
- **ci:** adapt ui ci to new workflow ([f617b20](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/f617b20cb2dc63955a81cd9a3a001104c6cc6430))
- **README.md:** Fake fix to trigger tagging ([4d28b62](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/4d28b629fcf5f096b31aa17e0dfe879e967438a0))
- **registry:** fix the registry route check ([8c52d6d](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/8c52d6d323eaab5db63d4eed08514000b5bbe06d))
- **registry:** selinux patch to handle BZ[#2033639](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/issues/2033639) ([69aab83](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/69aab83a994a7d7d5acae1cdcdad01f2fc268afb))

### Features

- **ansible:** add function edge to export edge kubeconfig ([7938dd8](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/7938dd8e84c53495480eb0b786703098684b4ec6))
- **ansible:** add hub kubeconfig alias to bashrc ([fbf4624](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/fbf4624fc61d9e790f354c4acdfcc10623cecff0))
- **ansible:** add some minor tweak to bashrc ([a3f333d](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/a3f333d23a7b288e977ab94cfbb9f417760a2942))
- **ci:** show in motd when a job has failed ([6a56d33](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/6a56d3354198c1be26438837228b85739e7e20f3))

# [1.5.0](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/1.4.5...1.5.0) (2022-05-23)

### Bug Fixes

- **ansible:** control hub and edge function errors properly ([14f24d5](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/14f24d508d92fba5c3c879b555d7aa23fc41e134))
- **ci:** adapt ui ci to new workflow ([f617b20](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/f617b20cb2dc63955a81cd9a3a001104c6cc6430))
- **registry:** fix the registry route check ([8c52d6d](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/8c52d6d323eaab5db63d4eed08514000b5bbe06d))
- **registry:** selinux patch to handle BZ[#2033639](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/issues/2033639) ([69aab83](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/69aab83a994a7d7d5acae1cdcdad01f2fc268afb))

### Features

- **ansible:** add function edge to export edge kubeconfig ([7938dd8](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/7938dd8e84c53495480eb0b786703098684b4ec6))
- **ansible:** add hub kubeconfig alias to bashrc ([fbf4624](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/fbf4624fc61d9e790f354c4acdfcc10623cecff0))
- **ansible:** add some minor tweak to bashrc ([a3f333d](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/a3f333d23a7b288e977ab94cfbb9f417760a2942))
- **ci:** show in motd when a job has failed ([6a56d33](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/6a56d3354198c1be26438837228b85739e7e20f3))

# [1.5.0](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/1.4.5...1.5.0) (2022-05-23)

### Bug Fixes

- **ansible:** control hub and edge function errors properly ([14f24d5](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/14f24d508d92fba5c3c879b555d7aa23fc41e134))
- **ci:** adapt ui ci to new workflow ([f617b20](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/f617b20cb2dc63955a81cd9a3a001104c6cc6430))
- **registry:** fix the registry route check ([8c52d6d](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/8c52d6d323eaab5db63d4eed08514000b5bbe06d))
- **registry:** selinux patch to handle BZ[#2033639](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/issues/2033639) ([69aab83](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/69aab83a994a7d7d5acae1cdcdad01f2fc268afb))

### Features

- **ansible:** add function edge to export edge kubeconfig ([7938dd8](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/7938dd8e84c53495480eb0b786703098684b4ec6))
- **ansible:** add hub kubeconfig alias to bashrc ([fbf4624](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/fbf4624fc61d9e790f354c4acdfcc10623cecff0))
- **ansible:** add some minor tweak to bashrc ([a3f333d](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/a3f333d23a7b288e977ab94cfbb9f417760a2942))
- **ci:** show in motd when a job has failed ([6a56d33](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/6a56d3354198c1be26438837228b85739e7e20f3))

# [1.5.0](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/1.4.5...1.5.0) (2022-05-23)

### Bug Fixes

- **ansible:** control hub and edge function errors properly ([14f24d5](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/14f24d508d92fba5c3c879b555d7aa23fc41e134))
- **registry:** fix the registry route check ([8c52d6d](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/8c52d6d323eaab5db63d4eed08514000b5bbe06d))
- **registry:** selinux patch to handle BZ[#2033639](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/issues/2033639) ([69aab83](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/69aab83a994a7d7d5acae1cdcdad01f2fc268afb))

### Features

- **ansible:** add function edge to export edge kubeconfig ([7938dd8](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/7938dd8e84c53495480eb0b786703098684b4ec6))
- **ansible:** add hub kubeconfig alias to bashrc ([fbf4624](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/fbf4624fc61d9e790f354c4acdfcc10623cecff0))
- **ansible:** add some minor tweak to bashrc ([a3f333d](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/a3f333d23a7b288e977ab94cfbb9f417760a2942))
- **ci:** show in motd when a job has failed ([6a56d33](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/6a56d3354198c1be26438837228b85739e7e20f3))

# [1.5.0](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/1.4.5...1.5.0) (2022-05-23)

### Bug Fixes

- **ansible:** control hub and edge function errors properly ([14f24d5](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/14f24d508d92fba5c3c879b555d7aa23fc41e134))
- **registry:** fix the registry route check ([8c52d6d](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/8c52d6d323eaab5db63d4eed08514000b5bbe06d))
- **registry:** selinux patch to handle BZ[#2033639](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/issues/2033639) ([69aab83](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/69aab83a994a7d7d5acae1cdcdad01f2fc268afb))

### Features

- **ansible:** add function edge to export edge kubeconfig ([7938dd8](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/7938dd8e84c53495480eb0b786703098684b4ec6))
- **ansible:** add hub kubeconfig alias to bashrc ([fbf4624](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/fbf4624fc61d9e790f354c4acdfcc10623cecff0))
- **ansible:** add some minor tweak to bashrc ([a3f333d](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/a3f333d23a7b288e977ab94cfbb9f417760a2942))
- **ci:** show in motd when a job has failed ([6a56d33](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/6a56d3354198c1be26438837228b85739e7e20f3))

# [1.5.0](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/1.4.5...1.5.0) (2022-05-20)

### Bug Fixes

- **ansible:** control hub and edge function errors properly ([14f24d5](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/14f24d508d92fba5c3c879b555d7aa23fc41e134))
- **registry:** fix the registry route check ([8c52d6d](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/8c52d6d323eaab5db63d4eed08514000b5bbe06d))
- **registry:** selinux patch to handle BZ[#2033639](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/issues/2033639) ([69aab83](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/69aab83a994a7d7d5acae1cdcdad01f2fc268afb))

### Features

- **ansible:** add function edge to export edge kubeconfig ([7938dd8](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/7938dd8e84c53495480eb0b786703098684b4ec6))
- **ansible:** add hub kubeconfig alias to bashrc ([fbf4624](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/fbf4624fc61d9e790f354c4acdfcc10623cecff0))
- **ansible:** add some minor tweak to bashrc ([a3f333d](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/a3f333d23a7b288e977ab94cfbb9f417760a2942))
- **ci:** show in motd when a job has failed ([6a56d33](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/6a56d3354198c1be26438837228b85739e7e20f3))

# [1.5.0](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/1.4.5...1.5.0) (2022-05-19)

### Bug Fixes

- **ansible:** control hub and edge function errors properly ([14f24d5](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/14f24d508d92fba5c3c879b555d7aa23fc41e134))
- **registry:** fix the registry route check ([8c52d6d](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/8c52d6d323eaab5db63d4eed08514000b5bbe06d))
- **registry:** selinux patch to handle BZ[#2033639](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/issues/2033639) ([69aab83](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/69aab83a994a7d7d5acae1cdcdad01f2fc268afb))

### Features

- **ansible:** add function edge to export edge kubeconfig ([7938dd8](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/7938dd8e84c53495480eb0b786703098684b4ec6))
- **ansible:** add hub kubeconfig alias to bashrc ([fbf4624](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/fbf4624fc61d9e790f354c4acdfcc10623cecff0))
- **ci:** show in motd when a job has failed ([6a56d33](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/6a56d3354198c1be26438837228b85739e7e20f3))

# [1.5.0](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/1.4.5...1.5.0) (2022-05-19)

### Bug Fixes

- **ansible:** control hub and edge function errors properly ([14f24d5](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/14f24d508d92fba5c3c879b555d7aa23fc41e134))
- **registry:** fix the registry route check ([8c52d6d](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/8c52d6d323eaab5db63d4eed08514000b5bbe06d))

### Features

- **ansible:** add function edge to export edge kubeconfig ([7938dd8](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/7938dd8e84c53495480eb0b786703098684b4ec6))
- **ansible:** add hub kubeconfig alias to bashrc ([fbf4624](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/fbf4624fc61d9e790f354c4acdfcc10623cecff0))
- **ci:** show in motd when a job has failed ([6a56d33](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/6a56d3354198c1be26438837228b85739e7e20f3))

# [1.5.0](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/1.4.5...1.5.0) (2022-05-19)

### Bug Fixes

- **ansible:** control hub and edge function errors properly ([14f24d5](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/14f24d508d92fba5c3c879b555d7aa23fc41e134))

### Features

- **ansible:** add function edge to export edge kubeconfig ([7938dd8](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/7938dd8e84c53495480eb0b786703098684b4ec6))
- **ansible:** add hub kubeconfig alias to bashrc ([fbf4624](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/fbf4624fc61d9e790f354c4acdfcc10623cecff0))
- **ci:** show in motd when a job has failed ([6a56d33](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/6a56d3354198c1be26438837228b85739e7e20f3))

# [1.5.0](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/1.4.5...1.5.0) (2022-05-19)

### Features

- **ansible:** add function edge to export edge kubeconfig ([7938dd8](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/7938dd8e84c53495480eb0b786703098684b4ec6))
- **ansible:** add hub kubeconfig alias to bashrc ([fbf4624](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/fbf4624fc61d9e790f354c4acdfcc10623cecff0))
- **ci:** show in motd when a job has failed ([6a56d33](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/6a56d3354198c1be26438837228b85739e7e20f3))

# [1.5.0](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/1.4.5...1.5.0) (2022-05-18)

### Features

- **ansible:** add hub kubeconfig alias to bashrc ([fbf4624](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/fbf4624fc61d9e790f354c4acdfcc10623cecff0))
- **ci:** show in motd when a job has failed ([6a56d33](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/6a56d3354198c1be26438837228b85739e7e20f3))

## [1.4.5](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/1.4.4...1.4.5) (2022-05-18)

### Bug Fixes

- **Makefile:** Use RELEASE and not Branch for mage tag ([0f63eb1](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/0f63eb190a21788d0b521b1d741b11bf9878c6f3))

## [1.4.4](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/1.4.3...1.4.4) (2022-05-17)

### Bug Fixes

- **ansible:** current duplicated word ([67b0ff2](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/67b0ff23c30f232872f728b43f1f5a9074c98a4b))

## [1.4.3](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/1.4.2...1.4.3) (2022-05-17)

### Bug Fixes

- **ansible:** add final white space... ([c4a440d](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/c4a440d8345a10a2ea15936d0d6bc76625e662d9))

## [1.4.2](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/1.4.1...1.4.2) (2022-05-17)

### Bug Fixes

- **ansible:** small motd fix ([1de6c8b](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/1de6c8b01a7dd4decdb732c13eeab7b6f4041ebd))

## [1.4.1](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/1.4.0...1.4.1) (2022-05-17)

### Bug Fixes

- **finish-deployment/deploy.sh:** remove extra > ([41eac39](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/41eac39928949a64ecc28f0c32fe823698b8d063))

# [1.4.0](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/1.3.1...1.4.0) (2022-05-17)

### Features

- **ansible:** add set-motd disclaimer ([49cb940](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/49cb940e8dde55309733f50ddac513c202b98afc))

## [1.3.1](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/1.3.0...1.3.1) (2022-05-17)

### Bug Fixes

- **ansible:** bashrc messages break ansible ([d4e424f](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/d4e424f6433814c16b5bc9d961ccb89e3ef3eace))

# [1.3.0](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/1.2.6...1.3.0) (2022-05-17)

### Features

- **ansible:** add set-motd help in bashrc ([ddecce6](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/ddecce65fd17c034403ffa2fd9100a1e931b7e85))

## [1.2.6](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/1.2.5...1.2.6) (2022-05-16)

### Bug Fixes

- **ci:** reduce set-motd verbose ([5dd7082](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/5dd7082b8b4adfd096fc64ef9bc73ab40b45af9f))

## [1.2.5](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/1.2.4...1.2.5) (2022-05-16)

### Bug Fixes

- **ci:** prevent this workflow to fail because of motd ([23c9ce5](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/23c9ce540b8baf6417b7201e17ba11ad425a789c))

## [1.2.4](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/1.2.3...1.2.4) (2022-05-16)

### Bug Fixes

- **ansible:** clean repo before cloning ([c21c3bf](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/c21c3bf1d50e0615bf879906b61f89994f2334e7))

## [1.2.3](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/1.2.2...1.2.3) (2022-05-16)

### Bug Fixes

- **setmotd:** removing max args in setmotd set ([6768ac2](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/6768ac2ac546e4a7ca4bb5884f5f217c47bf65de))

## [1.2.2](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/1.2.1...1.2.2) (2022-05-16)

### Bug Fixes

- **deploy:** fix csr-autoapprover serviceaccount path ([88c1525](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/88c15259306b26a61d56324adb60dbf4b03dbd49))

## [1.2.1](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/1.2.0...1.2.1) (2022-05-13)

### Bug Fixes

- **ci:** motd message now shows info properly ([02207ae](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/02207ae53445120169db11c5865873ae137fe5b2))

# [1.2.0](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/1.1.14...1.2.0) (2022-05-13)

### Features

- **ci:** set motd when a worker is in use ([8d167a5](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/8d167a5506d238e3a0a417f1133f6f77923fdf0d))

## [1.1.14](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/1.1.13...1.1.14) (2022-05-11)

### Bug Fixes

- Error on catalogSource certificate detection ([ffe170c](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/ffe170c75be43e1ec55a127d9de10aa1aaae9a1c))

## [1.1.13](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/1.1.12...1.1.13) (2022-05-11)

### Bug Fixes

- Error on catalogSource certificate detection ([62a4c5d](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/62a4c5d7f55f29834a178a81edf9233428012542))

## [1.1.12](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/1.1.11...1.1.12) (2022-05-04)

### Bug Fixes

- MGMT-10096 - Avoid storage overcommit when OCS is deployed ([#198](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/issues/198)) ([64cd65d](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/64cd65df15775023d63f7e63489d8c5671d827bb))
- Root is not necessary to execute the bootstrap script, removing that req ([597bfd4](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/597bfd42d9183f104a9aea740af4e9f457ed47c4))

## [1.1.11](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/1.1.10...1.1.11) (2022-04-05)

### Bug Fixes

- Changing OCS version from 4.8 to 4.9 ([c1cd9ac](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/c1cd9ac9df9acbf7742485b95612ca510b96eb9c))

## [1.1.9](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/1.1.8...1.1.9) (2022-04-05)

### Bug Fixes

- **deploy-ocs/deploy.sh:** commit e669b8636a9667cc304c9f8d6ebb033abae07a7a introduced /dev/ in the edgeclusters.yaml but didn't update OCS wipe disk script ([2c4e345](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/2c4e34544109629e820afc9fd95cac0f2f500139))

## [1.1.8](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/1.1.7...1.1.8) (2022-04-04)

### Bug Fixes

- **verify_prefly-edgeclusters.sh:** remove leftoverline ([d1754ab](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/d1754ab0e17fbfcbf10dea12eb81159f32989f55))

## [1.1.7](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/1.1.6...1.1.7) (2022-04-04)

### Bug Fixes

- set the correct path on copy ([a5e9f22](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/a5e9f22fd695da250f96106997aa29d6a3ee2aa9))

## [1.1.6](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/1.1.5...1.1.6) (2022-04-04)

### Bug Fixes

- use container image without git clone ([a07804a](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/a07804ac7d71ea091f27c1baf4a4e3a47fced32b))

## [1.1.5](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/1.1.4...1.1.5) (2022-04-04)

### Bug Fixes

- run tekton task without git clone ([c7a52ba](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/c7a52ba2025d49c0aa6642d163d42178f1c2befb))

## [1.1.4](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/1.1.3...1.1.4) (2022-04-01)

### Bug Fixes

- use right variable name ([bc2a957](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/bc2a95707ddf6feb7900df870e638e8ae600f5b5))

## [1.1.3](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/1.1.2...1.1.3) (2022-04-01)

### Bug Fixes

- Listen to new published releases ([8c68e61](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/8c68e61ccd9c0946537d55fd32b4ad4f2832c490))

# [1.1.0](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/1.0.2...1.1.0) (2022-04-01)

### Features

- add gh workflow to publish container image on tags ([ae774f0](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/ae774f0f527b8d2717b5c7a015754539231675ff))

## [1.0.2](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/1.0.1...1.0.2) (2022-03-31)

### Bug Fixes

- **common-git-fetch.yaml:** remove ndots option in resolv.conf to avoid issues in DNS resolution ([d17d6de](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/d17d6decb28dca293d9dc6eeb5b6c7918bdc5296))

## [0.0.5](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/0.0.4...0.0.5) (2021-12-23)

### Reverts

- Revert "fixing the unexplicable issue with reigstry phase pre" ([fdaee71](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/fdaee71b6096256f40bd259d7a79610b537ad5ae))
- Revert "deploy-edgecluster/configure_disconnected.sh" ([e5945cb](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/e5945cb48dc6511cd7383632cbdc5efda95e9d16))
- Revert "trying to fix with splitting edgeclusters kubeconfig depends on the stage" ([318a682](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/318a6824b294e96981a002275f4a0ddbfff5adbe))

## [0.0.4](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/0.0.3...0.0.4) (2021-12-14)

### Bug Fixes

- add waitfor for the disconnected after machineconfig ([5a27fbf](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/5a27fbfb48cb7a7adad7cb3580ab5439df241153))

## [0.0.3](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/0.0.2...0.0.3) (2021-12-14)

### Bug Fixes

- try to solve machine config restart ([7cc6533](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/7cc65333aee143b042a870208e066954da574505))

## [0.0.2](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/v0.0.1...0.0.2) (2021-12-13)

### Bug Fixes

- Error replacing vars with envsub ([12597ac](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/12597ac466985e2576b5cba94f59d904c41ee8fc))
