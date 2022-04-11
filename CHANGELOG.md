## [1.1.11](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/1.1.10...1.1.11) (2022-04-05)

### Bug Fixes

- Changing OCS version from 4.8 to 4.9 ([c1cd9ac](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/c1cd9ac9df9acbf7742485b95612ca510b96eb9c))

## [1.1.9](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/1.1.8...1.1.9) (2022-04-05)

### Bug Fixes

- **deploy-ocs/deploy.sh:** commit e669b8636a9667cc304c9f8d6ebb033abae07a7a introduced /dev/ in the spokes.yaml but didn't update OCS wipe disk script ([2c4e345](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/2c4e34544109629e820afc9fd95cac0f2f500139))

## [1.1.8](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/1.1.7...1.1.8) (2022-04-04)

### Bug Fixes

- **verify_prefly-spokes.sh:** remove leftoverline ([d1754ab](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/d1754ab0e17fbfcbf10dea12eb81159f32989f55))

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
- Revert "deploy-spoke/configure_disconnected.sh" ([e5945cb](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/e5945cb48dc6511cd7383632cbdc5efda95e9d16))
- Revert "trying to fix with splitting spokes kubeconfig depends on the stage" ([318a682](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/318a6824b294e96981a002275f4a0ddbfff5adbe))

## [0.0.4](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/0.0.3...0.0.4) (2021-12-14)

### Bug Fixes

- add waitfor for the disconnected after machineconfig ([5a27fbf](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/5a27fbfb48cb7a7adad7cb3580ab5439df241153))

## [0.0.3](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/0.0.2...0.0.3) (2021-12-14)

### Bug Fixes

- try to solve machine config restart ([7cc6533](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/7cc65333aee143b042a870208e066954da574505))

## [0.0.2](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/compare/v0.0.1...0.0.2) (2021-12-13)

### Bug Fixes

- Error replacing vars with envsub ([12597ac](https://github.com/rh-ecosystem-edge/ztp-pipeline-relocatable/commit/12597ac466985e2576b5cba94f59d904c41ee8fc))
