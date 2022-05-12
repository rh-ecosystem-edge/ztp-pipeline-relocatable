package main

import (
	"fmt"
	"io/ioutil"
	"os"
	"strings"
	"testing"
)

func Test_setMotd(t *testing.T) {

	// Create temporal testfile
	tempPattern := "test-setmotd-*"
	f, err := os.CreateTemp("", tempPattern)
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
	defer os.Remove(f.Name())

	type args struct {
		motd       *stringFlag
		user       *stringFlag
		pr         *stringFlag
		customPath *stringFlag
	}
	tests := []struct {
		name    string
		args    args
		want    [5]string
		wantErr bool
	}{
		// Tests array
		{
			"Test 1: Contains only date. No error returned expected.",
			args{
				motd:       &stringFlag{false, ""},
				user:       &stringFlag{false, ""},
				pr:         &stringFlag{false, ""},
				customPath: &stringFlag{true, f.Name()},
			},
			[5]string{"Updated at", "", "", "", ""},
			false,
		},
		{
			"Test 2: Contains date and motd. No error returned expected.",
			args{
				motd:       &stringFlag{true, "OCATOPIC"},
				user:       &stringFlag{false, ""},
				pr:         &stringFlag{false, ""},
				customPath: &stringFlag{true, f.Name()},
			},
			[5]string{"Updated at", "OCATOPIC", "", "", ""},
			false,
		},
		{
			"Test 2: Contains nothing. Error returned expected.",
			args{
				motd:       &stringFlag{false, "false"},
				user:       &stringFlag{false, "false"},
				pr:         &stringFlag{false, "false"},
				customPath: &stringFlag{false, f.Name()},
			},
			[5]string{"false", "false", "false", "false", "false"},
			true,
		},
	}

	for i, currentTest := range tests {
		t.Run(currentTest.name, func(t *testing.T) {
			setMotd(currentTest.args.motd, currentTest.args.user, currentTest.args.pr, currentTest.args.customPath)

			// Read the testfile and insert into a byte buffer
			// Convert the buffer to a string so Contains can be used
			bufferFile, err := ioutil.ReadFile(f.Name())
			if err != nil {
				panic(err)
			}
			s := bufferFile
			stringsFile := string(s)

			// Loop over tests[i].want, which is the array of strings we want
			// to find inside the file.
			// Then use Contains to look for the wanted string inside the file
			for stringWanted := range tests[i].want {

				if !tests[i].wantErr {
					// wantErr = false, so we expect to find the string
					if !strings.Contains(stringsFile, currentTest.want[stringWanted]) {
						os.Exit(1)
					}
				} else {
					// wantErr = true, so we don't expect to find the string
					if strings.Contains(stringsFile, currentTest.want[stringWanted]) {
						os.Exit(1)
					}
				}
			}
		})
	}
}
