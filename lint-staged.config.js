export default {
	'*.{js,ts,json,jsonc,md}': ['biome format --write', 'biome check --write'],
	'*.sh': ['shfmt -w -i 4 -ci', 'shellcheck'],
};
