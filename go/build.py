#!/usr/bin/env python3
# -*- coding: utf-8 -*-

#
# Copyright (c) 2022 Red Hat Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except
# in compliance with the License. You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License
# is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
# or implied. See the License for the specific language governing permissions and limitations under
# the License.
#

"""
This is the build utility for the project.
"""

import os
import subprocess
import shutil

import click
import click_default_group

@click.group(
    cls=click_default_group.DefaultGroup,
    default="build",
    default_if_no_args=True,
)
def main():
    """
    Build utility.
    """

@main.command()
def build():
    """
    Build the binary.
    """
    subprocess.run(
        check=True,
        args=["go", "build", "-o", "oc-ztp"],
    )

@main.command()
def test():
    """
    Run tests.
    """
    subprocess.run(
        check=True,
        args=["ginkgo", "run", "-r"],
    )

@main.command()
def lint():
    """
    Run linter.
    """
    subprocess.run(
        check=True,
        args=["golangci-lint", "run"],
    )

@main.command()
def setup():
     """
     Prepare the development environment.
     """
     # Install Ginkgo:
     if shutil.which("ginkgo") is None:
         print("Installing ginkgo")
         subprocess.run(
             check=True,
             args=["go", "install", "github.com/onsi/ginkgo/v2/ginkgo@v2.5.1"],
         )
     else:
         print("Ginkgo is already installed")

     # Install golangci-lint:
     if shutil.which("golangci-lint") is None:
         print("Installing golangci-lint")
         subprocess.run(
             check=True,
             args=["go", "install", "github.com/golangci/golangci-lint/cmd/golangci-lint@v1.50.1"],
         )
     else:
         print("Golangci-lint is already installed")


if __name__ == '__main__':
    main()
