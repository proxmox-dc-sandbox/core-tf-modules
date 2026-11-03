## Objective

<!-- What problem does this pull request solve? Link the issue if any. -->

## Changes

<!-- Module(s) impacted, new inputs/outputs, breaking changes -->

## Design rules

- [ ] No backend block added
- [ ] No provider configuration added (`required_providers` only)
- [ ] No `terraform_remote_state`
- [ ] No credentials or environment-specific defaults
- [ ] No cloud-init templates in the module interface

## Local checks run

```shell
tofu fmt -check -recursive 01-foundation 02-networking 03-compute modules examples
for d in 01-foundation/examples/test-local \
         02-networking/examples/test-local \
         03-compute/examples/test-local; do
  (cd "$d" && tofu init -backend=false -input=false && tofu validate)
done
```

- [ ] `tofu fmt` passes for all modules and examples
- [ ] `tofu validate` passes for all modules
- [ ] Terragrunt HCL files are formatted and valid (client changes)

## Breaking changes

<!-- Breaking changes require a major version bump and a migration note. -->

- None

## Version bump

- [ ] Not applicable (no public release affected)
- [ ] Patch / minor bump — CHANGELOG.md updated
- [ ] Major bump — migration note added
