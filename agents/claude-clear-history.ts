#!/usr/bin/env bun

/**
 * Claude History Cleanup Tool
 *
 * Clears all conversation history from ~/.claude.json
 */

import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { resolve } from 'node:path';

// Types
interface HistoryEntry {
	display: string;
	pastedContents: Record<string, unknown>;
}

interface ProjectData {
	history: HistoryEntry[];
	[key: string]: unknown;
}

interface ClaudeConfig {
	projects: Record<string, ProjectData>;
	[key: string]: unknown;
}

function readClaudeConfig(filePath: string): ClaudeConfig {
	if (!existsSync(filePath)) {
		console.error(`Error: File not found: ${filePath}`);
		process.exit(1);
	}

	const content = readFileSync(filePath, 'utf-8');
	const config = JSON.parse(content) as ClaudeConfig;

	if (!config.projects || typeof config.projects !== 'object') {
		console.error("Error: Invalid .claude.json structure: missing 'projects' field");
		process.exit(1);
	}

	return config;
}

function clearHistory(config: ClaudeConfig): number {
	let totalCleared = 0;

	for (const projectData of Object.values(config.projects)) {
		totalCleared += projectData.history.length;
		projectData.history = [];
	}

	return totalCleared;
}

function writeClaudeConfig(filePath: string, config: ClaudeConfig): void {
	const content = JSON.stringify(config, null, 2);
	writeFileSync(filePath, content, 'utf-8');
}

function main(): void {
	const filePath = resolve(homedir(), '.claude.json');

	const config = readClaudeConfig(filePath);
	const totalCleared = clearHistory(config);
	writeClaudeConfig(filePath, config);

	console.log(`\x1b[34mCleared ${totalCleared} conversation(s) from Claude history\x1b[0m`);
}

main();
