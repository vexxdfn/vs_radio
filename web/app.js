(() => {
'use strict';

const RES = (window.GetParentResourceName && window.GetParentResourceName()) || 'vs_radio';
const $ = (s) => document.querySelector(s);

const state = {
  open: false,
  channel: 0,
  volume: 50,
  preMute: 50,
  entry: '',
  tuning: null,
  labels: {},
  min: 1,
  max: 999,
  keySounds: true,
  radioSounds: true,
  tx: false,
  rx: false,
  clock: '--:--',
};

async function post(endpoint, body) {
  try {
    const res = await fetch(`https://${RES}/${endpoint}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(body || {}),
    });
    return await res.json();
  } catch {
    return { ok: false };
  }
}

let actx = null;

function ctx() {
  if (!actx) actx = new (window.AudioContext || window.webkitAudioContext)();
  if (actx.state === 'suspended') actx.resume();
  return actx;
}

function tone(freq, dur, gain, type = 'sine') {
  const c = ctx();
  const start = c.currentTime;
  const o = c.createOscillator();
  const g = c.createGain();
  o.type = type;
  o.frequency.value = freq;
  g.gain.setValueAtTime(0, start);
  g.gain.linearRampToValueAtTime(gain, start + 0.004);
  g.gain.setValueAtTime(gain, start + dur - 0.008);
  g.gain.linearRampToValueAtTime(0, start + dur);
  o.connect(g);
  g.connect(c.destination);
  o.start(start);
  o.stop(start + dur + 0.01);
}

const customSounds = { key_up: null, key_down: null };

async function loadCustomSound(name) {
  for (const ext of ['ogg', 'mp3', 'wav']) {
    try {
      const res = await fetch(`sounds/${name}.${ext}`);
      if (!res.ok) continue;
      const data = await res.arrayBuffer();
      if (!data.byteLength) continue;
      customSounds[name] = await ctx().decodeAudioData(data);
      return;
    } catch { }
  }
}

loadCustomSound('key_up');
loadCustomSound('key_down');

function playBuffer(buffer, gain) {
  const c = ctx();
  const src = c.createBufferSource();
  const g = c.createGain();
  src.buffer = buffer;
  g.gain.value = gain;
  src.connect(g);
  g.connect(c.destination);
  src.start();
}

const level = () => (state.radioSounds ? state.volume / 100 : 0);

function talkStart() {
  const L = level();
  if (!L) return;
  if (customSounds.key_up) return playBuffer(customSounds.key_up, L);
  tone(1400, 0.09, 0.12 * L);
}

function talkStop() {
  const L = level();
  if (!L) return;
  if (customSounds.key_down) return playBuffer(customSounds.key_down, L);
  tone(850, 0.09, 0.12 * L);
}

function beep(freq = 1450, dur = 0.035) {
  if (!state.keySounds) return;
  try { tone(freq, dur, 0.035, 'square'); } catch { }
}

const pad3 = (n) => String(n).padStart(3, '0');

function render() {
  const lcd = $('#lcd');
  const chEl = $('#lcd-ch');
  const label = $('#lcd-label');

  lcd.classList.toggle('on', state.channel > 0);
  $('#bezel').classList.toggle('lit', state.channel > 0);
  chEl.classList.toggle('entering', !!state.entry);
  chEl.classList.toggle('tuning', state.tuning !== null && !state.entry);

  if (state.entry) {
    chEl.textContent = (state.entry + '___').slice(0, 3);
    label.textContent = 'ENTER CHANNEL';
  } else if (state.tuning !== null) {
    chEl.textContent = pad3(state.tuning);
    label.textContent = state.labels[String(state.tuning)] || 'TUNING';
  } else if (state.channel) {
    chEl.textContent = pad3(state.channel);
    label.textContent = state.labels[String(state.channel)] || 'CHANNEL';
  } else {
    chEl.textContent = '---';
    label.textContent = 'NO CHANNEL';
  }

  const lit = Math.round(state.volume / 20);
  document.querySelectorAll('#vol-bars i').forEach((el, i) => el.classList.toggle('on', i < lit));
  document.querySelector('.vol').classList.toggle('muted', state.volume === 0);

  $('#clock').textContent = state.clock;
  $('#pill-tx').classList.toggle('on', state.tx);
  $('#pill-rx').classList.toggle('on', state.rx && !state.tx);

  const led = $('#led');
  led.classList.toggle('tx', state.tx);
  led.classList.toggle('rx', state.rx && !state.tx);
}

async function join(value) {
  const ch = Number(value);
  state.entry = '';
  state.tuning = null;
  if (!ch || ch < state.min || ch > state.max) { render(); return; }
  const res = await post('join', { channel: ch });
  state.channel = res.channel ?? state.channel;
  beep(res.ok ? 1900 : 420, res.ok ? 0.05 : 0.12);
  render();
}

async function leave() {
  state.entry = '';
  state.tuning = null;
  await post('leave', {});
  state.channel = 0;
  state.rx = false;
  beep(700, 0.06);
  render();
}

let stepTimer = null;
function step(delta) {
  const base = state.tuning ?? (state.channel || state.min - (delta > 0 ? 1 : 0));
  let next = base + delta;
  if (next > state.max) next = state.min;
  if (next < state.min) next = state.max;
  state.tuning = next;
  state.entry = '';
  beep(1300, 0.02);
  render();
  clearTimeout(stepTimer);
  stepTimer = setTimeout(() => join(next), 350);
}

let volTimer = null;
function setVolume(v) {
  state.volume = Math.max(0, Math.min(100, v));
  render();
  clearTimeout(volTimer);
  volTimer = setTimeout(() => post('volume', { value: state.volume }), 120);
}

function changeVolume(delta) {
  setVolume(state.volume + delta);
  beep(900 + state.volume * 8, 0.02);
}

function toggleMute() {
  if (state.volume > 0) {
    state.preMute = state.volume;
    setVolume(0);
    beep(500, 0.05);
  } else {
    setVolume(state.preMute || 50);
    beep(1500, 0.05);
  }
}

function confirm() {
  if (state.entry) return join(state.entry);
  if (state.tuning !== null) {
    clearTimeout(stepTimer);
    return join(state.tuning);
  }
  beep(900);
}

function pressKey(key) {
  if (key === 'clr') {
    beep(900);
    state.entry = state.entry.slice(0, -1);
  } else if (key === 'ent') {
    return confirm();
  } else if (/^\d$/.test(key) && state.entry.length < 3) {
    beep();
    state.tuning = null;
    state.entry += key;
  }
  render();
}

function close() {
  state.open = false;
  $('#radio').hidden = true;
  post('close', {});
}

document.querySelector('.keypad').addEventListener('click', (e) => {
  const k = e.target.closest('[data-key]');
  if (k) pressKey(k.dataset.key);
});

document.querySelector('.softkeys').addEventListener('click', (e) => {
  const s = e.target.closest('[data-soft]');
  if (!s) return;
  if (s.dataset.soft === 'up') step(1);
  else if (s.dataset.soft === 'down') step(-1);
  else leave();
});

document.querySelector('.navrow').addEventListener('click', (e) => {
  const n = e.target.closest('[data-nav]');
  if (!n) return;
  switch (n.dataset.nav) {
    case 'up': step(1); break;
    case 'down': step(-1); break;
    case 'left': changeVolume(-10); break;
    case 'right': changeVolume(10); break;
    case 'ok': confirm(); break;
    case 'off': leave(); break;
    case 'mute': toggleMute(); break;
  }
});

$('#knob-ch').addEventListener('wheel', (e) => { e.preventDefault(); step(e.deltaY < 0 ? 1 : -1); }, { passive: false });
$('#knob-vol').addEventListener('wheel', (e) => { e.preventDefault(); changeVolume(e.deltaY < 0 ? 10 : -10); }, { passive: false });

const input = $('#lcd-input');
input.addEventListener('focus', () => post('typing', { value: true }));
input.addEventListener('blur', () => post('typing', { value: false }));
input.addEventListener('input', () => {
  input.value = input.value.replace(/\D/g, '').slice(0, 3);
  state.entry = input.value;
  state.tuning = null;
  render();
});
input.addEventListener('keydown', (e) => {
  if (e.key === 'Enter') {
    e.preventDefault();
    const v = input.value;
    input.value = '';
    input.blur();
    join(v);
  } else if (e.key === 'Escape') {
    e.preventDefault();
    e.stopPropagation();
    input.value = '';
    state.entry = '';
    input.blur();
    render();
  }
});

document.addEventListener('keydown', (e) => {
  if (e.key !== 'Escape' || !state.open || document.activeElement === input) return;
  e.preventDefault();
  close();
});

window.addEventListener('message', (e) => {
  const d = e.data || {};
  switch (d.action) {
    case 'open': {
      state.open = true;
      state.channel = d.channel || 0;
      if (typeof d.volume === 'number') state.volume = d.volume;
      state.labels = d.labels || {};
      state.min = d.min || 1;
      state.max = d.max || 999;
      state.keySounds = d.sounds !== false;
      state.entry = '';
      state.tuning = null;
      document.documentElement.style.setProperty('--scale', d.scale || 1);
      $('#radio').hidden = false;
      const lcd = $('#lcd');
      lcd.classList.remove('boot');
      void lcd.offsetWidth;
      lcd.classList.add('boot');
      render();
      break;
    }

    case 'close':
      state.open = false;
      if (document.activeElement === input) input.blur();
      $('#radio').hidden = true;
      break;

    case 'clock':
      state.clock = `${String(d.h).padStart(2, '0')}:${String(d.m).padStart(2, '0')}`;
      if (state.open) $('#clock').textContent = state.clock;
      break;

    case 'tx': {
      const on = !!d.value;
      if (typeof d.vol === 'number') state.volume = d.vol;
      state.radioSounds = d.sfx !== false;
      if (on !== state.tx) (on ? talkStart : talkStop)();
      state.tx = on;
      if (state.open) render();
      break;
    }

    case 'rx':
      state.rx = !!d.value;
      if (state.open) render();
      break;
  }
});

})();
