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
