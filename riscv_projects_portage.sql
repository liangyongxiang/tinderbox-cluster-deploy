--
-- PostgreSQL database dump
--

-- Dumped from database version 13.2
-- Dumped by pg_dump version 13.5

-- Started on 2022-01-24 01:14:57 CET

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 2324 (class 0 OID 155945)
-- Dependencies: 213
-- Data for Name: projects_portage; Type: TABLE DATA; Schema: public; Owner: buildbot
--

INSERT INTO public.projects_portage VALUES (1, '20c3ba2b-a85f-42ec-bd0e-c70e175d940d', 'make.profile', 'default/linux/riscv/20.0/rv64gc/lp64d/systemd');
INSERT INTO public.projects_portage VALUES (2, '20c3ba2b-a85f-42ec-bd0e-c70e175d940d', 'repos.conf', 'gentoo');
INSERT INTO public.projects_portage VALUES (3, '1b2d0f00-4035-4bb4-9ed4-e3e55f98d26e', 'make.profile', 'default/linux/riscv/20.0/rv64gc/lp64d/no-multilib');
INSERT INTO public.projects_portage VALUES (4, '1b2d0f00-4035-4bb4-9ed4-e3e55f98d26e', 'repos.conf', 'gentoo');
INSERT INTO public.projects_portage VALUES (5, '19321b0c-0ec4-4766-978d-5494a563546e', 'make.profile', 'default/linux/riscv/20.0/rv64gc/lp64d');
INSERT INTO public.projects_portage VALUES (6, '19321b0c-0ec4-4766-978d-5494a563546e', 'repos.conf', 'gentoo');


--
-- TOC entry 2332 (class 0 OID 0)
-- Dependencies: 214
-- Name: projects_portage_id_seq; Type: SEQUENCE SET; Schema: public; Owner: buildbot
--

SELECT pg_catalog.setval('public.projects_portage_id_seq', 1, false);


-- Completed on 2022-01-24 01:14:57 CET

--
-- PostgreSQL database dump complete
--

