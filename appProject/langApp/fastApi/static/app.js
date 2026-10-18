let editor;
let socket = null;
let currentJobId = null;

const languageDefaults = {
  python: 'print("Hello, World!")',
  javascript: 'console.log("Hello, World!");',
  go: 'package main\n\nimport "fmt"\n\nfunc main() {\n\tfmt.Println("Hello, World!")\n}'
};

// Monaco Editor Setup
require.config({ paths: { vs: 'https://cdnjs.cloudflare.com/ajax/libs/monaco-editor/0.40.0/min/vs' } });
require(['vs/editor/editor.main'], function () {
  editor = monaco.editor.create(document.getElementById('editor'), {
    value: languageDefaults.python,
    language: 'python',
    theme: 'vs-dark',
    automaticLayout: true,
  });

  document.getElementById('language-select').addEventListener('change', (e) => {
    const lang = e.target.value;
    monaco.editor.setModelLanguage(editor.getModel(), lang);
    editor.setValue(languageDefaults[lang] || '// Write your code here');
    document.getElementById('editor-lang').textContent = lang;
  });
});

// Run code
document.getElementById('run-btn').addEventListener('click', async () => {
  const code = editor.getValue();
  const language = document.getElementById('language-select').value;
  clearTerminal();

  try {
    const res = await fetch('/execute', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ code, language }),
    });

    const data = await res.json();
    currentJobId = data.job_id;
    connectWebSocket(currentJobId);
  } catch (err) {
    appendToTerminal(`Error: ${err.message}`);
  }
});

// Clear terminal
document.getElementById('clear-btn').addEventListener('click', clearTerminal);

function clearTerminal() {
  const terminal = document.getElementById('terminal');
  terminal.textContent = '';
}

function setStatus(state, text) {
  const dot = document.getElementById('status-dot');
  const label = document.getElementById('status-text');
  if (state === 'connected') {
    dot.classList.add('connected');
  } else {
    dot.classList.remove('connected');
  }
  label.textContent = text;
}

// WebSocket logic
function connectWebSocket(jobId) {
  if (socket) socket.close();

  const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
  const wsUrl = `${protocol}//${window.location.host}/ws/${jobId}`;
  socket = new WebSocket(wsUrl);
  const input = document.getElementById('terminal-input');

  setStatus('connecting', 'Connecting...');

  socket.onopen = () => {
    appendToTerminal(`Connected to session: ${jobId}\n`);
    input.disabled = false;
    input.focus();
    setStatus('connected', 'Live');
  };

  socket.onmessage = (event) => {
    appendToTerminal(event.data);
  };

  socket.onerror = (e) => {
    console.error('WebSocket error:', e);
    appendToTerminal('\nWebSocket error occurred.');
    setStatus('error', 'Error');
  };

  socket.onclose = (e) => {
    console.warn('WebSocket closed:', e.reason || e);
    input.disabled = true;
    appendToTerminal(`\nSession ended: ${e.reason || 'No reason given.'}`);
    setStatus('idle', 'Idle');
  };
}

// Append text to terminal
function appendToTerminal(text) {
  const terminal = document.getElementById('terminal');
  terminal.textContent += text;
  terminal.scrollTop = terminal.scrollHeight;
}

// Interactive terminal input
document.getElementById('terminal-input').addEventListener('keydown', (e) => {
  if (!socket || socket.readyState !== WebSocket.OPEN) return;

  if (e.key === 'Enter') {
    e.preventDefault();
    const input = e.target;
    const line = input.value;
    socket.send(line + '\n');
    appendToTerminal(line + '\n');
    input.value = '';
  }
});
