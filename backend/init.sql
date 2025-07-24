--
-- PostgreSQL database dump
--

-- Dumped from database version 17.5
-- Dumped by pg_dump version 17.5

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
-- Name: clase_id_seq; Type: SEQUENCE; Schema: public; Owner: pg_database_owner
--

CREATE SEQUENCE public.clase_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.clase_id_seq OWNER TO pg_database_owner;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: clase; Type: TABLE; Schema: public; Owner: pg_database_owner
--

CREATE TABLE public.clase (
    nrc integer NOT NULL,
    horainicio time without time zone NOT NULL,
    horafinal time without time zone NOT NULL,
    aula character varying,
    dia character varying NOT NULL,
    id integer DEFAULT nextval('public.clase_id_seq'::regclass) NOT NULL
);


ALTER TABLE public.clase OWNER TO pg_database_owner;

--
-- Name: curso; Type: TABLE; Schema: public; Owner: pg_database_owner
--

CREATE TABLE public.curso (
    nrc integer NOT NULL,
    tipo character varying NOT NULL,
    codigomateria character varying NOT NULL,
    profesorid character varying,
    nrcteorico integer,
    groupid integer,
    campus character varying,
    cuposdisponibles integer,
    cupostotales integer,
    nombremateria character varying NOT NULL
);


ALTER TABLE public.curso OWNER TO pg_database_owner;

--
-- Name: materia; Type: TABLE; Schema: public; Owner: pg_database_owner
--

CREATE TABLE public.materia (
    codigomateria character varying NOT NULL,
    creditos integer NOT NULL,
    nombre character varying NOT NULL
);


ALTER TABLE public.materia OWNER TO pg_database_owner;

--
-- Name: profesor; Type: TABLE; Schema: public; Owner: pg_database_owner
--

CREATE TABLE public.profesor (
    bannerid character varying NOT NULL,
    nombre character varying NOT NULL
);


ALTER TABLE public.profesor OWNER TO pg_database_owner;

--
-- Name: clase clase_pkey; Type: CONSTRAINT; Schema: public; Owner: pg_database_owner
--

ALTER TABLE ONLY public.clase
    ADD CONSTRAINT clase_pkey PRIMARY KEY (id);


--
-- Name: curso curso_pkey; Type: CONSTRAINT; Schema: public; Owner: pg_database_owner
--

ALTER TABLE ONLY public.curso
    ADD CONSTRAINT curso_pkey PRIMARY KEY (nrc);


--
-- Name: materia materia_pkey; Type: CONSTRAINT; Schema: public; Owner: pg_database_owner
--

ALTER TABLE ONLY public.materia
    ADD CONSTRAINT materia_pkey PRIMARY KEY (codigomateria, nombre);


--
-- Name: profesor profesor_pkey; Type: CONSTRAINT; Schema: public; Owner: pg_database_owner
--

ALTER TABLE ONLY public.profesor
    ADD CONSTRAINT profesor_pkey PRIMARY KEY (bannerid);


--
-- Name: clase clase_nrc_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pg_database_owner
--

ALTER TABLE ONLY public.clase
    ADD CONSTRAINT clase_nrc_fkey FOREIGN KEY (nrc) REFERENCES public.curso(nrc);


--
-- Name: curso curso_codigomateria_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pg_database_owner
--

ALTER TABLE ONLY public.curso
    ADD CONSTRAINT curso_codigomateria_fkey FOREIGN KEY (codigomateria, nombremateria) REFERENCES public.materia(codigomateria, nombre);


--
-- Name: curso curso_nrcteorico_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pg_database_owner
--

ALTER TABLE ONLY public.curso
    ADD CONSTRAINT curso_nrcteorico_fkey FOREIGN KEY (nrcteorico) REFERENCES public.curso(nrc);


--
-- Name: curso curso_profesorid_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pg_database_owner
--

ALTER TABLE ONLY public.curso
    ADD CONSTRAINT curso_profesorid_fkey FOREIGN KEY (profesorid) REFERENCES public.profesor(bannerid);


--
-- PostgreSQL database dump complete
--
