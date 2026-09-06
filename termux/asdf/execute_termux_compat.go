package execute

import (
	"os/exec"
)

func termuxCommand(name string, arg ...string) *exec.Cmd {
	return exec.Command(name, arg...)
}
