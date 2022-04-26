package hcp

import (
	"bytes"
	"flag"
	"os"
	"path/filepath"
	"testing"
	"text/template"

	"github.com/stretchr/testify/require"
)

type HCPTemplate struct {
	VnetRegion     string
	HVNRegion      string
	ClusterID      string
	SubscriptionID string
	VnetRgName     string
	VnetName       string
	SubnetName     string
}

const (
	hcpRootDir = "../../hcp-ui-templates"
)

// update allows golden files to be updated based on the current output.
var update = flag.Bool("update", false, "update golden files")

func TestHCPTemplates(t *testing.T) {
	cases := map[string]struct {
		name           string
		templatePath   string
		templateValues HCPTemplate
	}{
		"vm": {
			templatePath: filepath.Join(hcpRootDir, "vm", "main.tf"),
			templateValues: HCPTemplate{
				VnetRegion: "westus2",
				HVNRegion:  "westus2",
				ClusterID:  "consul-quickstart-1634271483588",
			},
		},
		"vm-existing-vnet": {
			templatePath: filepath.Join(hcpRootDir, "vm-existing-vnet", "main.tf"),
			templateValues: HCPTemplate{
				VnetRegion:     "westus2",
				HVNRegion:      "westus2",
				ClusterID:      "consul-quickstart-1634271483588",
				SubscriptionID: "26310ff2-35ad-4839-83fb-0f82f258779f",
				VnetRgName:     "myvnetresourcegroup",
				VnetName:       "myvnetname",
				SubnetName:     "mysubnetname",
			},
		},
	}

	for name, tc := range cases {
		t.Run(name, func(t *testing.T) {
			r := require.New(t)
			temp, err := template.ParseFiles(tc.templatePath)
			r.NoError(err)

			var buf bytes.Buffer
			r.NoError(temp.Execute(&buf, tc.templateValues))

			r.Equal(golden(t, name, buf.String()), buf.String())
		})
	}
}

// golden returns the byte array of the requested golden file, in order to
// compare against the test-generated value. If the -update flag was passed,
// this also updates the golden file itself.
func golden(t *testing.T, name string, got string) string {
	t.Helper()

	golden := filepath.Join("testdata", name+".golden")

	// Update the golden file if the update flag was passed in.
	if *update && len(got) != 0 {
		require.NoError(t, os.WriteFile(golden, []byte(got), 0644))
		return got
	}

	data, err := os.ReadFile(golden)
	require.NoError(t, err)

	return string(data)
}
