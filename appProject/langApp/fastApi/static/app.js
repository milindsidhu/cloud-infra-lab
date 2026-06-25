<script>
let editor;
let socket = null;
let currentJobId = null;

const languageDefaults = {
  python: 'print("Hello, World!")',
  javascript: 'console.log("Hello, World!");',
  go: 'package main\n\nimport "fmt"\n\nfunc main() {\n\tfmt.Println("Hello, World!")\n}',
  java: 'public class Main {\n\tpublic static void main(String[] args) {\n\t\tSystem.out.println("Hello, World!");\n\t}\n}',
  csharp: 'using System;\n\nclass Program {\n\tstatic void Main() {\n\t\tConsole.WriteLine("Hello, World!");\n\t}\n}'
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

// WebSocket logic
function connectWebSocket(jobId) {
  if (socket) socket.close();

  const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
  const wsUrl = `${protocol}//${window.location.host}/ws/${jobId}`;
  socket = new WebSocket(wsUrl);

  socket.onopen = () => {
    appendToTerminal(`Connected to session: ${jobId}\n`);
  };

  socket.onmessage = (event) => {
    appendToTerminal(event.data);
  };

  socket.onerror = (e) => {
    console.error('WebSocket error:', e);
    alert('WebSocket connection failed.');
    appendToTerminal('\nWebSocket error occurred.');
  };

  socket.onclose = (e) => {
    console.warn('WebSocket closed:', e.reason || e);
    alert('Session ended.');
    appendToTerminal(`\nSession ended: ${e.reason || 'No reason given.'}`);
  };
}

// Append text to terminal
function appendToTerminal(text) {
  const terminal = document.getElementById('terminal');
  terminal.textContent += text;
  terminal.scrollTop = terminal.scrollHeight;
}

// Interactive terminal input
document.getElementById('terminal').addEventListener('keydown', (e) => {
  if (!socket || socket.readyState !== WebSocket.OPEN) return;

  const key = e.key;
  if (key === 'Enter') {
    e.preventDefault();
    socket.send('\n');
    appendToTerminal('\n');
  } else if (key.length === 1) {
    e.preventDefault();
    socket.send(key);
    appendToTerminal(key);
  } else if (key === 'Backspace') {
    e.preventDefault();
    socket.send('\x7f'); // ASCII DEL for backspace
    const terminal = document.getElementById('terminal');
    terminal.textContent = terminal.textContent.slice(0, -1);
  }
});

// Make terminal content editable for user input
document.getElementById('terminal').setAttribute('tabindex', '0');
document.getElementById('terminal').setAttribute('contenteditable', 'true');
</script>
