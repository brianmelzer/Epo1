/* FERVEUR — interaction layer */
(function () {
  'use strict';

  /* ---- Nav: shrink + theme swap on scroll ---- */
  var nav = document.querySelector('.nav');
  function onScroll() {
    if (!nav) return;
    if (window.scrollY > 60) nav.classList.add('scrolled');
    else nav.classList.remove('scrolled');
  }
  window.addEventListener('scroll', onScroll, { passive: true });
  onScroll();

  /* ---- Mobile menu ---- */
  var burger = document.querySelector('.burger');
  var menu = document.querySelector('.mobile-menu');
  if (burger && menu) {
    burger.addEventListener('click', function () {
      menu.classList.toggle('open');
      document.body.style.overflow = menu.classList.contains('open') ? 'hidden' : '';
    });
    menu.querySelectorAll('a').forEach(function (a) {
      a.addEventListener('click', function () {
        menu.classList.remove('open');
        document.body.style.overflow = '';
      });
    });
  }

  /* ---- Scroll reveal ---- */
  var revealEls = document.querySelectorAll('.reveal');
  if ('IntersectionObserver' in window) {
    var io = new IntersectionObserver(function (entries) {
      entries.forEach(function (e) {
        if (e.isIntersecting) {
          e.target.classList.add('in');
          io.unobserve(e.target);
        }
      });
    }, { threshold: 0.15 });
    revealEls.forEach(function (el) { io.observe(el); });
  } else {
    revealEls.forEach(function (el) { el.classList.add('in'); });
  }

  /* ---- Newsletter (front-end only) ---- */
  var form = document.querySelector('.news form');
  if (form) {
    form.addEventListener('submit', function (e) {
      e.preventDefault();
      var ok = form.parentNode.querySelector('.ok');
      var input = form.querySelector('input');
      if (input && input.value.indexOf('@') > 0) {
        if (ok) ok.textContent = 'Merci. Welcome to the Maison Ferveur list.';
        input.value = '';
      } else if (ok) {
        ok.textContent = 'Please enter a valid email address.';
      }
    });
  }

  /* ---- Lightweight cart counter (demo) ---- */
  var count = 0;
  var counter = document.querySelector('[data-cart-count]');
  document.querySelectorAll('[data-buy]').forEach(function (btn) {
    btn.addEventListener('click', function (e) {
      e.preventDefault();
      count++;
      if (counter) counter.textContent = '(' + count + ')';
      var label = btn.textContent;
      btn.textContent = 'Added ✦';
      setTimeout(function () { btn.textContent = label; }, 1400);
    });
  });

  /* ---- Active nav link by pathname ---- */
  var path = location.pathname.split('/').pop() || 'index.html';
  document.querySelectorAll('.nav__links a, .mobile-menu a').forEach(function (a) {
    var href = a.getAttribute('href');
    if (href === path || (path === 'index.html' && href === 'index.html')) a.classList.add('active');
  });
})();
