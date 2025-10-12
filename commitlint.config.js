export default {
	extends: ['@commitlint/config-conventional'],
	rules: {
		'type-enum': [2, 'always', ['feat', 'fix', 'refactor', 'docs', 'chore', 'style']],
		'scope-empty': [2, 'never'],
		'scope-enum': [
			2,
			'always',
			[
				'shell',
				'editor',
				'terminal',
				'system',
				'homebrew',
				'scripts',
				'docs',
				'deps',
				'repo',
			],
		],
		'subject-empty': [2, 'never'],
		'subject-case': [2, 'always', ['lower-case', 'sentence-case']],
		'header-max-length': [2, 'always', 100],
		'subject-full-stop': [2, 'never', '.'],
		'body-max-line-length': [0, 'always', Infinity],
	},
	helpUrl: 'https://github.com/conventional-changelog/commitlint/#what-is-commitlint',
};
