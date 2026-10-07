// Taipei-City-Dashboard-BE/global/global_test.go
package global

import (
	"os"
	"os/exec"
	"strings"
	"testing"
)

// TestHelperPrintLM is not a real test: when GO_WANT_LM_HELPER=1 it prints the
// value the real package-level config reader produced, then returns.
func TestHelperPrintLM(t *testing.T) {
	if os.Getenv("GO_WANT_LM_HELPER") != "1" {
		t.Skip("helper for the subprocess tests below")
	}
	os.Stdout.WriteString("SHARED_LIBRARY_PATH=" + LM.SharedLibraryPath + "\n")
}

// resolveSharedLibraryPath loads the package in a fresh process so the real
// initialisers read the environment we choose.
func resolveSharedLibraryPath(t *testing.T, ortPath *string) string {
	t.Helper()
	cmd := exec.Command(os.Args[0], "-test.run=^TestHelperPrintLM$", "-test.v")
	env := []string{}
	for _, kv := range os.Environ() {
		if !strings.HasPrefix(kv, "ORT_LIBRARY_PATH=") {
			env = append(env, kv)
		}
	}
	env = append(env, "GO_WANT_LM_HELPER=1")
	if ortPath != nil {
		env = append(env, "ORT_LIBRARY_PATH="+*ortPath)
	}
	cmd.Env = env
	out, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("child process failed: %v\n%s", err, out)
	}
	for _, line := range strings.Split(string(out), "\n") {
		if v, ok := strings.CutPrefix(line, "SHARED_LIBRARY_PATH="); ok {
			return v
		}
	}
	t.Fatalf("child did not print SHARED_LIBRARY_PATH:\n%s", out)
	return ""
}

func TestLMConfigSharedLibraryPathDefault(t *testing.T) {
	if got := resolveSharedLibraryPath(t, nil); got != "/usr/lib/libonnxruntime.so" {
		t.Fatalf("default SharedLibraryPath = %q, want /usr/lib/libonnxruntime.so", got)
	}
}

func TestLMConfigSharedLibraryPathOverride(t *testing.T) {
	override := "/opt/homebrew/lib/libonnxruntime.dylib"
	if got := resolveSharedLibraryPath(t, &override); got != override {
		t.Fatalf("overridden SharedLibraryPath = %q, want %q", got, override)
	}
}
