package main

import (
	"flag"
	"fmt"
	"log"
	"os"
	"time"
)

const (
	helpMsg string = `
	Usage: set-motd [set|unset|help]
	
	set [-motd string] [-user string] [-pr link] [-path /foo/bar]
	  - motd: set custom message
	  - user: set user using the server
	  - pr:	set pull-request being tested
	  - path: set custom path (Default: /etc/motd)
	
	unset
	
	help
	
	`

	unsetHelpMsg string = `
	Usage: set-motd unset
	Clears /etc/motd
	
	`

	setHelpMsg string = `
	Usage: set-motd set [-motd string] [-user string] [-pr link]
	  - motd: set custom message
	  - user: set user using the server
	  - pr:	set pull-request being tested
	  - path: set custom path (Default: /etc/motd)
	
	`
)

type stringFlag struct {
	set   bool
	value string
}

func (sf *stringFlag) Set(x string) error {
	sf.value = x
	sf.set = true
	return nil
}

func (sf *stringFlag) String() string {
	return sf.value
}

func setMotd(motd *stringFlag, user *stringFlag, pr *stringFlag, customPath *stringFlag) {

	if len(os.Args) == 2 || len(os.Args) > 10 {
		fmt.Print(setHelpMsg)
		os.Exit(1)
	}

	currentTime := time.Now()
	var motdMsg string = fmt.Sprintf("Updated at %s\n", currentTime.Format(time.UnixDate))

	if motd.set {
		motdMsg = fmt.Sprintf("%s%s\n", motdMsg, motd.String())
	}

	if pr.set {
		motdMsg = fmt.Sprintf("%sPull Request %s test initiated by %s\n", motdMsg, pr.String(), user.String())
	}

	if user.set && !pr.set {
		motdMsg = fmt.Sprintf("%sUsed by %s\n", motdMsg, user.String())
	}

	// Clean file
	var path string = customPath.String()
	if err := os.Truncate(path, 0); err != nil {
		log.Printf("Failed to truncate: %v", err)
	}

	// Open file
	var f, err = os.OpenFile(path, os.O_RDWR, 0644)
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
	defer f.Close()

	// Write motd
	_, err = f.WriteString(motdMsg)
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
}

func unsetMotd() {
	if len(os.Args) > 2 {
		fmt.Print(unsetHelpMsg)
		os.Exit(1)
	}

	// Clear file
	if err := os.Truncate("/etc/motd", 0); err != nil {
		log.Printf("Failed to truncate: %v", err)
	}

	// Open file
	var f, err = os.OpenFile("/etc/motd", os.O_RDWR, 0644)
	if err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
	defer f.Close()

	// Write motd
	var unsetMotd string = "Server free to use\n"
	n, err := f.WriteString(unsetMotd)
	if err != nil {
		fmt.Println(err, n)
		os.Exit(1)
	}
}

func printHelp() {
	fmt.Print(helpMsg)
	os.Exit(1)
}

func main() {

	var setVarMotd stringFlag
	var setVarUser stringFlag
	setVarUser.value = "ZTPFW Github Actions"
	var setVarPR stringFlag
	var setCustomPath stringFlag
	setCustomPath.value = "/etc/motd"

	setCmd := flag.NewFlagSet("set", flag.ExitOnError)
	setCmd.Var(&setVarMotd, "motd", "Set MOTD")
	setCmd.Var(&setVarUser, "user", "Set User")
	setCmd.Var(&setVarPR, "pr", "Set Pull Request")
	setCmd.Var(&setCustomPath, "path", "Set custom path, defaults to /etc/motd")

	if len(os.Args) < 2 {
		printHelp()
		os.Exit(1)
	}

	switch os.Args[1] {
	case "set":
		setCmd.Parse(os.Args[2:])
		setMotd(&setVarMotd, &setVarUser, &setVarPR, &setCustomPath)
	case "unset":
		unsetMotd()
	case "help":
		printHelp()
	default:
		printHelp()
	}
}
